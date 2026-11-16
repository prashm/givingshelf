# app/services/item_request_service.rb
class ItemRequestService
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
    raise "Cannot accept a cancelled request" if item_request.cancelled?
    ActiveRecord::Base.transaction do
      item_request.accepted!
      item_request.item.requested!
      # Mark other pending requests for this item as In Review; leave declined/cancelled/completed ones alone
      item_request.item.item_requests.where.not(id: item_request.id).pending.update_all(status: :in_review)
    end
  end

  def decline!
    require_item_request!
    raise "Cannot decline a cancelled request" if item_request.cancelled?
    item_request.declined!
  end

  def complete!
    require_item_request!
    raise "Cannot complete a cancelled request" if item_request.cancelled?
    raise "Can only complete an accepted request" unless item_request.accepted?
    ActiveRecord::Base.transaction do
      item_request.completed!
      item_request.item.donated!
    end
  end

  def cancel!
    require_item_request!
    raise "Cannot cancel a completed request" if item_request.completed?
    ActiveRecord::Base.transaction do
      item_request.item.available! if item_request.accepted?
      item_request.cancelled!
    end
  end

  def uncancel!
    require_item_request!
    raise "Can only uncancel a cancelled request" unless item_request.cancelled?
    item_request.pending!
  end

  def mark_as_in_review!
    require_item_request!
    item_request.in_review! if item_request.pending?
  end

  # When a donor claims a wishlist item: mark request in review and set owner without moving item to REQUESTED.
  def match_wishlist_donor!(donor_user)
    require_item_request!
    return unless item_request.pending?
    item_request.update!(status: :in_review, owner: donor_user)
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
    case status&.to_s
    when "completed"
      "Completed"
    when "accepted"
      "Accepted"
    when "declined"
      "Declined"
    when "in_review"
      "In Review"
    when "cancelled"
      "Cancelled"
    else
      "Pending"
    end
  end

  private

  def require_item_request!
    raise ArgumentError, "item_request is required" if item_request.nil?
  end

  def notify_item_owner
    ItemRequestNotificationJob.perform_later(self.item_request)
  end
end
