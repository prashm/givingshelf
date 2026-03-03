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
      self.item_request.uncancel!
    else
      raise "Not authorized" unless self.item_request.item.owner?(current_user)
      raise "Cannot update a cancelled request" if self.item_request.cancelled?

      case action_type
      when "accept"
        self.item_request.accept!
      when "decline"
        self.item_request.decline!
      when "complete"
        self.item_request.complete!
      when "mark_as_viewed"
        self.item_request.mark_as_in_review!
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

    self.item_request.cancel!
    true
  rescue => e
    @errors << e.message
    false
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

  private

  def notify_item_owner
    ItemRequestNotificationJob.perform_later(self.item_request)
  end
end
