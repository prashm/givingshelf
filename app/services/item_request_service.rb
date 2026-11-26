# app/services/item_request_service.rb
class ItemRequestService
  attr_accessor :item_request
  attr_reader :errors

  # Fixed notes on the events the GS-8 close-out writes. B1 (GS-9 Part B) uses the declined one to
  # tell a close-out from the owner declining.
  CLOSE_OUT_DECLINED_NOTE = "This item went to another requester.".freeze
  CLOSE_OUT_MOVED_NOTE = "This copy went to another requester. You've been moved to a new wish for the same item.".freeze
  # Fixed notes on the events written when the owner deletes the item (GS-12). The owner's own note,
  # if any, follows as a second paragraph (see .note_after).
  ITEM_REMOVED_NOTE = "The owner removed this item.".freeze
  ITEM_REMOVED_MOVED_NOTE = "The donor removed this copy. You've been moved to a new wish for the same item.".freeze

  # A fixed event text followed by someone's own note as a second paragraph, if they wrote one.
  def self.note_after(fixed_text, note)
    [ fixed_text, note.to_s.strip.presence ].compact.join("\n\n")
  end

  # Why a request message can't be used, or nil if it's fine.
  def self.initial_message_error(message)
    message = message.to_s.strip
    length = ItemRequest::INITIAL_MESSAGE_LENGTH
    return "Message can't be blank" if message.blank?
    return "Message is too short (minimum is #{length.min} characters)" if message.length < length.min
    return "Message is too long (maximum is #{length.max} characters)" if message.length > length.max
    nil
  end

  # JSON for one thread message. A transition event also carries the status it moved to, and an
  # `event` key naming what happened, which the UI turns into wording for each viewer.
  def self.message_json(message)
    request = message.item_request
    {
      id: message.id,
      content: message.content,
      user_id: message.user_id,
      user_name: message.user.display_name,
      user_role: message_author_role(message, request),
      created_at: message.created_at.iso8601,
      request_transition_status: message.request_transition_status,
      event: event_kind(message, request)
    }
  end

  # The author's part in the request. A wish's giver is its donor; anyone else's is its owner.
  def self.message_author_role(message, request)
    return "requester" if message.user_id == request.requester_id
    request.item.wishlist_item? ? "donor" : "owner"
  end

  # What a transition event means. Most are just the status they moved to ("accepted"), but a
  # few statuses can be reached in more than one way, and the thread words those differently.
  # A plain chat message has no event (nil).
  def self.event_kind(message, request)
    status = message.request_transition_status
    case status&.to_sym
    when :pending
      if message.user_id != request.requester_id
        "moved"
      elsif message.id == request.initial_message&.id
        "requested"
      else
        "reopened"
      end
    when :in_review
      # On a wish, the donor is the one who moves a request into review (by fulfilling it, or by
      # opening a later wisher's request), so it reads as a donor having been found.
      request.item.wishlist_item? ? "donor_found" : "viewed"
    when :declined
      if message.content == CLOSE_OUT_DECLINED_NOTE
        "closed_out"
      elsif message.content.to_s.start_with?(ITEM_REMOVED_NOTE)
        "item_removed"
      else
        "declined"
      end
    when :accepted, :completed, :cancelled
      status
    else
      nil
    end
  end

  def initialize(item_request = nil)
    @item_request = item_request
    @errors = []
  end

  def create_request(requester, item_id, message)
    item = Item.find(item_id)

    unless requester.profile_complete?
      raise "User profile is incomplete."
    end

    item_service = ItemService.new(item)
    unless item_service.item_can_be_requested_by?(requester)
      reason = "Cannot request this item"
      if item_service.item_cannot_be_requested_by_reason.present?
        reason = "#{reason}: #{item_service.item_cannot_be_requested_by_reason}"
      end
      raise reason
    end
    message_error = self.class.initial_message_error(message)
    raise message_error if message_error

    ActiveRecord::Base.transaction { start_request!(requester, item, message) }
    @item_request
  rescue ActiveRecord::RecordInvalid => e
    @errors += e.record.errors.full_messages
    @item_request = nil
  rescue => e
    @errors << e.message
    @item_request = nil
  end

  # Creates the request and its initial PENDING event, whose note is the request message. Runs in
  # the caller's transaction; callers check the message first (see .initial_message_error).
  def start_request!(requester, item, message)
    @item_request = requester.item_requests.create!(item: item)
    record_event!(@item_request, :pending, requester, message)
    @item_request
  end

  # note: optional text from whoever made the change, shown under the event in the thread.
  def update_request(current_user, action_type, note: nil)
    case action_type
    when "uncancel"
      raise "Not authorized" unless self.item_request.requester == current_user
      uncancel!(note: note)
    else
      raise "Not authorized" unless self.item_request.item.owner?(current_user)
      raise "Cannot update a cancelled request" if self.item_request.cancelled?

      case action_type
      when "accept"
        accept!(actor: current_user, note: note)
      when "decline"
        decline!(actor: current_user, note: note)
      when "complete"
        complete!(actor: current_user, note: note)
      when "mark_as_viewed"
        mark_as_in_review!(actor: current_user)
      else
        raise "Invalid action"
      end
    end
    true
  rescue => e
    @errors << e.message
    false
  end

  def cancel_request(requester, note: nil)
    # Only the requester can cancel their own request
    if self.item_request.requester != requester
      raise "Not authorized"
    end

    cancel!(note: note)
    true
  rescue => e
    @errors << e.message
    false
  end

  # Each transition below records an event in the request's thread, authored by whoever made the
  # change (actor defaults to the item's owner, or the requester for cancel/uncancel), with their
  # optional note. The event commits or rolls back with the change.
  def accept!(actor: nil, note: nil)
    require_item_request!
    with_locked_item do |item|
      item_request.guard_transition!(:accepted)
      raise "This item has already been donated" if item.donated?
      raise "Another request for this item has already been accepted" if item_request.other_requests.accepted.exists?
      waiting_ids = item_request.other_requests.awaiting_decision.pluck(:id)
      item_request.accepted!
      event = record_event!(item_request, :accepted, actor || item.user, note)
      # The other open requesters hear that someone else was chosen (GS-11).
      queue_item_notice!(event, UserNotification::KIND_OTHER_CHOSEN, waiting_ids)
      item.requested!
      # Mark other pending requests for this item as In Review; leave declined/cancelled/completed ones alone
      item_request.other_requests.pending.update_all(status: :in_review)
    end
  end

  def decline!(actor: nil, note: nil)
    require_item_request!
    with_locked_item do |item|
      item_request.guard_transition!(:declined)
      # Declining the accepted request frees the item for the other requesters, as cancel! does.
      was_accepted = item_request.accepted?
      item.available! if was_accepted
      item_request.declined!
      event = record_event!(item_request, :declined, actor || item.user, note)
      queue_available_again!(event) if was_accepted
    end
  end

  def complete!(actor: nil, note: nil)
    require_item_request!
    raise "Can only complete an accepted request" if item_request.pending? || item_request.in_review?
    with_locked_item do |item|
      item_request.guard_transition!(:completed)
      actor ||= item.user
      item_request.completed!
      record_event!(item_request, :completed, actor, note)
      item.donated!
      close_out_other_requests!(item, actor)
    end
    log_close_out
  end

  def cancel!(note: nil)
    require_item_request!
    with_locked_item do |item|
      item_request.guard_transition!(:cancelled)
      was_accepted = item_request.accepted?
      item.available! if was_accepted
      item_request.cancelled!
      event = record_event!(item_request, :cancelled, item_request.requester, note)
      queue_available_again!(event) if was_accepted
    end
  end

  def uncancel!(note: nil)
    require_item_request!
    raise "Can only uncancel a cancelled request" unless item_request.cancelled?
    with_locked_item do |item|
      item_request.guard_transition!(:pending)
      reason = uncancel_blocked_reason(item_request)
      raise reason if reason
      # A wish cancelled before a donor fulfilled it was never matched, so give it the current
      # owner; otherwise it would never show in their received requests.
      item_request.owner ||= item.user
      item_request.pending!
      record_event!(item_request, :pending, item_request.requester, note)
    end
  end

  # The owner opened the request. Only the real PENDING -> IN_REVIEW move writes an event, so
  # opening the page again writes nothing.
  def mark_as_in_review!(actor: nil)
    require_item_request!
    return unless item_request.pending?
    ActiveRecord::Base.transaction do
      item_request.in_review!
      record_event!(item_request, :in_review, actor || item_request.owner || item_request.item.user)
    end
  end

  # When a donor claims a wishlist item: mark request in review and set owner without moving item to REQUESTED.
  def match_wishlist_donor!(donor_user)
    require_item_request!
    return unless item_request.pending?
    item_request.update!(status: :in_review, owner: donor_user)
    record_event!(item_request, :in_review, donor_user)
  end

  # Gives each of `requests` (the item's open ones) a final result: wishers move to a new wish for the
  # same item, with a PENDING event carrying `moved_note`; requesters of a regular item are declined,
  # with a DECLINED event carrying `declined_note`. Every event is authored by `actor`. Runs in the
  # caller's transaction, with the item locked. Returns the new wish, or nil.
  # Used when an item is donated (GS-8) and when its owner deletes it (GS-12).
  def close_out_requests!(item, requests, actor, declined_note:, moved_note:)
    return nil if requests.empty?

    if item.wishlist_item?
      new_wish = ItemService.new(item).relist_as_wish!
      requests.each do |request|
        request.update!(item: new_wish, owner: nil, status: :pending)
        record_event!(request, :pending, actor, moved_note)
      end
      new_wish
    else
      requests.each do |request|
        request.declined!
        record_event!(request, :declined, actor, declined_note)
      end
      nil
    end
  end

  def requests_for_user(user, type)
    item_requests = []
    case type
    when "received"
      # Requests received for user's items
      item_requests = ItemRequest.for_item_owner(user)
        .includes(:item, :requester)
        .order(created_at: :desc)
    when "sent"
      # Requests sent by user
      item_requests = user.item_requests
        .includes(:item)
        .order(created_at: :desc)
    end
    item_requests
  end

  # JSON for a list of requests. Loads every request's initial message in one query, rather than
  # one query per request.
  def requests_json(requests)
    requests = requests.to_a
    initial_messages = Message.transitions
      .where(item_request_id: requests.map(&:id), request_transition_status: :pending)
      .order(:created_at, :id)
      .group_by(&:item_request_id)
    requests.map do |request|
      request_json(request, initial_message: initial_messages[request.id]&.first)
    end
  end

  # initial_message: the request's first PENDING event, when the caller already has it.
  def request_json(request, initial_message: request.initial_message)
    {
      id: request.id,
      status: request.status,
      status_display: request.status_label,
      message: initial_message&.content,
      created_at: request.created_at,
      updated_at: request.updated_at,
      can_update_status: request.can_update_status?,
      message_thread_writable: request.message_thread_writable?,
      **requester_actions(request),
      requester: {
        id: request.requester.id,
        name: request.requester.display_name,
        location: request.requester.location,
        verified: request.requester.verified?
      }
    }.merge(item_map(request.item))
  end

  def item_map(item)
    case item.type
    when Book.name
      { book: BookService.new.item_detail_map(item) }
    when Toy.name
      { toy: ToyService.new.item_detail_map(item) }
    else
      { item: item.as_json }
    end
  end

  def display_status(status)
    ItemRequest.status_label(status)
  end

  # What the requester may do with their own request right now.
  def requester_actions(request)
    {
      can_cancel: request.can_transition_to?(:cancelled),
      can_uncancel: request.cancelled? && uncancel_blocked_reason(request).nil?
    }
  end

  # Why a cancelled request can't be reopened right now, or nil if it can.
  def uncancel_blocked_reason(request)
    item = request.item
    return "This item has already been donated" if item.donated?
    if !(item.available? || item.wishlist?) || request.other_requests.accepted.exists?
      return "Another request for this item has already been accepted"
    end
    nil
  end

  private

  # Runs a transition in one transaction with the item row locked, so two owners/tabs (or an owner
  # and the requester) can't change the same item's requests at once.
  def with_locked_item
    ActiveRecord::Base.transaction do
      item = item_request.item
      item.lock!
      current_status = ItemRequest.where(id: item_request.id).pick(:status)
      raise "This request was just updated by someone else. Please refresh and try again." if current_status != item_request.status
      yield item
    end
  end

  # After a handoff, give every other request still awaiting a decision a final result.
  def close_out_other_requests!(item, actor)
    open_requests = item_request.other_requests.awaiting_decision.order(:created_at, :id).to_a
    new_wish = close_out_requests!(item, open_requests, actor,
      declined_note: CLOSE_OUT_DECLINED_NOTE, moved_note: CLOSE_OUT_MOVED_NOTE)
    @close_out = { item: item, requests: open_requests, new_wish: new_wish }
  end

  # Writes a transition event: request moved to `to_status`, caused by `author`, with an optional
  # note. Once everything commits, it's pushed to anyone viewing the thread and queued for email to
  # the other party (GS-11); a rollback drops all of it.
  def record_event!(request, to_status, author, note = nil)
    event = request.messages.create!(user: author, request_transition_status: to_status, content: note.to_s.strip.presence)
    ActiveRecord.after_all_transactions_commit do
      broadcast_event(event)
      RequestEventNotificationJob.perform_later(event.id)
    end
    event
  end

  # Queues, after commit, a notice to the requesters of `request_ids` about something that happened
  # to another request on their item (`kind` is a UserNotification kind; `event` caused it).
  def queue_item_notice!(event, kind, request_ids)
    return if request_ids.empty?
    ActiveRecord.after_all_transactions_commit { RequestEventNotificationJob.perform_later(event.id, kind, request_ids) }
  end

  # The accepted request fell through: tell the other open requesters the item is available again.
  def queue_available_again!(event)
    queue_item_notice!(event, UserNotification::KIND_AVAILABLE_AGAIN, item_request.other_requests.awaiting_decision.pluck(:id))
  end

  def broadcast_event(event)
    ActionCable.server.broadcast(
      "item_request_#{event.item_request_id}",
      { type: "message", message: self.class.message_json(event) }
    )
  rescue => e
    Rails.logger.warn "Couldn't broadcast request event #{event.id}: #{e.message}"
  end

  # Runs after commit. The emails to these requesters come with GS-11.
  def log_close_out
    return if @close_out.blank? || @close_out[:requests].empty?
    ids = @close_out[:requests].map(&:id)
    if @close_out[:new_wish]
      Rails.logger.info "Item #{@close_out[:item].id} donated; moved requests #{ids} to new wish #{@close_out[:new_wish].id}"
    else
      Rails.logger.info "Item #{@close_out[:item].id} donated; declined requests #{ids}"
    end
  end

  def require_item_request!
    raise ArgumentError, "item_request is required" if item_request.nil?
  end
end
