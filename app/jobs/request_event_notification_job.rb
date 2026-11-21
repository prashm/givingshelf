# Emails the person a request's status change affects (GS-11). ItemRequestService queues it after
# the change commits, once per transition event.
#
# - The recipient is the other party on the request, never the event's author. An ownerless wish
#   has no owner, so a requester's event on it emails nobody.
# - Each email is recorded in UserNotification first, so a retry or a repeated move never sends a
#   second one.
# - With a notice kind (KIND_OTHER_CHOSEN or KIND_AVAILABLE_AGAIN) it instead emails the requesters
#   of `request_ids`, the item's other open requests, about what the event did to their chances.
class RequestEventNotificationJob < ApplicationJob
  queue_as :default

  def perform(event_id, notice_kind = nil, request_ids = [])
    event = Message.find_by(id: event_id)
    return unless event&.transition?

    if notice_kind
      send_item_notices(event, notice_kind, request_ids)
    else
      send_event_email(event)
    end
  end

  private

  def send_event_email(event)
    request = event.item_request
    recipient = event.user_id == request.requester_id ? request.owner : request.requester
    return if recipient.nil? || recipient.id == event.user_id

    case ItemRequestService.event_kind(event, request)
    when "viewed"
      nil # Too minor to email.
    when "donor_found"
      # Keeps its own once-per-wish dedup (KIND_WISHLIST_AVAILABLE on the item).
      UserService.new.notify_wishlist_available_to_requester(item: request.item, item_request: request)
    when "requested"
      ItemRequestMailer.new_request_notification(request).deliver_later if first_notification?(recipient, event, UserNotification::KIND_REQUEST_EVENT)
    else
      RequestEventMailer.event_update(event, recipient).deliver_later if first_notification?(recipient, event, UserNotification::KIND_REQUEST_EVENT)
    end
  end

  def send_item_notices(event, kind, request_ids)
    # Only requests still waiting: one declined or cancelled since then needs no notice.
    ItemRequest.where(id: request_ids).awaiting_decision.includes(:requester).find_each do |request|
      next if request.requester_id == event.user_id
      next unless first_notification?(request.requester, event, kind)
      RequestEventMailer.item_notice(kind, request, event).deliver_later
    end
  end

  # Records that `user` was told about `event`; false if they already were.
  def first_notification?(user, event, kind)
    UserNotification.create!(user: user, notifiable: event, kind: kind, sent_at: Time.current)
    true
  rescue ActiveRecord::RecordNotUnique
    false
  end
end
