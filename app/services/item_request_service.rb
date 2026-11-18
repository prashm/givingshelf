# app/services/item_request_service.rb
class ItemRequestService
  # Allowed request status moves. DECLINED and COMPLETED are final; a CANCELLED request can only
  # be reopened (uncancel), and only while the item can still be given to it.
  TRANSITIONS = {
    ItemRequest::PENDING_STATUS => [ ItemRequest::IN_REVIEW_STATUS, ItemRequest::ACCEPTED_STATUS, ItemRequest::DECLINED_STATUS, ItemRequest::CANCELLED_STATUS ],
    ItemRequest::IN_REVIEW_STATUS => [ ItemRequest::ACCEPTED_STATUS, ItemRequest::DECLINED_STATUS, ItemRequest::CANCELLED_STATUS ],
    ItemRequest::ACCEPTED_STATUS => [ ItemRequest::COMPLETED_STATUS, ItemRequest::DECLINED_STATUS, ItemRequest::CANCELLED_STATUS ],
    ItemRequest::CANCELLED_STATUS => [ ItemRequest::PENDING_STATUS ],
    ItemRequest::DECLINED_STATUS => [],
    ItemRequest::COMPLETED_STATUS => []
  }.freeze

  TRANSITION_VERBS = {
    ItemRequest::IN_REVIEW_STATUS => "review",
    ItemRequest::ACCEPTED_STATUS => "accept",
    ItemRequest::DECLINED_STATUS => "decline",
    ItemRequest::COMPLETED_STATUS => "complete",
    ItemRequest::CANCELLED_STATUS => "cancel",
    ItemRequest::PENDING_STATUS => "uncancel"
  }.freeze

  attr_accessor :item_request
  attr_reader :errors

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

    @item_request = requester.item_requests.build(item: item, message: message)

    if @item_request.save
      notify_item_owner
    else
      @errors += @item_request.errors.full_messages
      @item_request = nil
    end
    @item_request
  rescue => e
    @errors << e.message
    @item_request = nil
  end

  def update_request(current_user, action_type)
    case action_type
    when "uncancel"
      raise "Not authorized" unless self.item_request.requester == current_user
      uncancel!
    else
      raise "Not authorized" unless self.item_request.item.owner?(current_user)
      raise "Cannot update a cancelled request" if self.item_request.cancelled?

      case action_type
      when "accept"
        accept!
      when "decline"
        decline!
      when "complete"
        complete!
      when "mark_as_viewed"
        mark_as_in_review!
      else
        raise "Invalid action"
      end
    end
    true
  rescue => e
    @errors << e.message
    false
  end

  def cancel_request(requester)
    # Only the requester can cancel their own request
    if self.item_request.requester != requester
      raise "Not authorized"
    end

    cancel!
    true
  rescue => e
    @errors << e.message
    false
  end

  def accept!
    require_item_request!
    with_locked_item do |item|
      guard_transition!(to: ItemRequest::ACCEPTED_STATUS)
      raise "This item has already been donated" if item.donated?
      raise "Another request for this item has already been accepted" if other_request_accepted?(item_request)
      item_request.update!(status: ItemRequest::ACCEPTED_STATUS)
      item.update!(status: ShareableItemStatus::REQUESTED)
      # Mark other pending requests for this item as In Review; leave declined/cancelled/completed ones alone
      item.item_requests.where.not(id: item_request.id).pending.update_all(status: ItemRequest::IN_REVIEW_STATUS)
    end
  end

  def decline!
    require_item_request!
    with_locked_item do |item|
      guard_transition!(to: ItemRequest::DECLINED_STATUS)
      # Declining the accepted request frees the item for the other requesters, as cancel! does.
      item.update!(status: ShareableItemStatus::AVAILABLE) if item_request.accepted?
      item_request.update!(status: ItemRequest::DECLINED_STATUS)
    end
  end

  def complete!
    require_item_request!
    raise "Can only complete an accepted request" if item_request.pending? || item_request.in_review?
    with_locked_item do |item|
      guard_transition!(to: ItemRequest::COMPLETED_STATUS)
      item_request.update!(status: ItemRequest::COMPLETED_STATUS)
      item.update!(status: ShareableItemStatus::DONATED)
    end
  end

  def cancel!
    require_item_request!
    with_locked_item do |item|
      guard_transition!(to: ItemRequest::CANCELLED_STATUS)
      item.update!(status: ShareableItemStatus::AVAILABLE) if item_request.accepted?
      item_request.update!(status: ItemRequest::CANCELLED_STATUS)
    end
  end

  def uncancel!
    require_item_request!
    raise "Can only uncancel a cancelled request" unless item_request.cancelled?
    with_locked_item do |item|
      guard_transition!(to: ItemRequest::PENDING_STATUS)
      reason = uncancel_blocked_reason(item_request)
      raise reason if reason
      # A wish cancelled before a donor fulfilled it was never matched, so give it the current
      # owner; otherwise it would never show in their received requests.
      item_request.owner ||= item.user
      item_request.update!(status: ItemRequest::PENDING_STATUS)
    end
  end

  def mark_as_in_review!
    require_item_request!
    item_request.update!(status: ItemRequest::IN_REVIEW_STATUS) if item_request.pending?
  end

  # When a donor claims a wishlist item: mark request in review and set owner without moving item to REQUESTED.
  def match_wishlist_donor!(donor_user)
    require_item_request!
    return unless item_request.pending?
    item_request.update!(status: ItemRequest::IN_REVIEW_STATUS, owner: donor_user)
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

  def request_json(request)
    {
      id: request.id,
      status: request.status,
      status_display: display_status(request.status),
      message: request.message,
      created_at: request.created_at,
      updated_at: request.updated_at,
      can_update_status: request.can_update_status?,
      can_cancel: can_transition?(request, ItemRequest::CANCELLED_STATUS),
      can_uncancel: request.cancelled? && uncancel_blocked_reason(request).nil?,
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
    case status
    when ItemRequest::COMPLETED_STATUS
      "Completed"
    when ItemRequest::ACCEPTED_STATUS
      "Accepted"
    when ItemRequest::DECLINED_STATUS
      "Declined"
    when ItemRequest::IN_REVIEW_STATUS
      "In Review"
    when ItemRequest::CANCELLED_STATUS
      "Cancelled"
    else
      "Pending"
    end
  end

  def can_transition?(request, to)
    TRANSITIONS.fetch(request.status, []).include?(to)
  end

  # Why a cancelled request can't be reopened right now, or nil if it can.
  def uncancel_blocked_reason(request)
    item = request.item
    return "This item has already been donated" if item.donated?
    if !(item.available? || item.wishlist?) || other_request_accepted?(request)
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

  def guard_transition!(to:)
    return if can_transition?(item_request, to)
    status = display_status(item_request.status).downcase
    article = status.match?(/\A[aeiou]/) ? "an" : "a"
    raise "Cannot #{TRANSITION_VERBS.fetch(to)} #{article} #{status} request"
  end

  def other_request_accepted?(request)
    request.item.item_requests.where.not(id: request.id).accepted.exists?
  end

  def require_item_request!
    raise ArgumentError, "item_request is required" if item_request.nil?
  end

  def notify_item_owner
    ItemRequestNotificationJob.perform_later(self.item_request)
  end
end
