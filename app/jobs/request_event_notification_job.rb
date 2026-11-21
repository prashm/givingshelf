require "net/smtp"

# Emails the person a request's status change affects (GS-11). ItemRequestService queues it after
# the change commits, once per transition event.
#
# - The recipient is the other party on the request, never the event's author. An ownerless wish
#   has no owner, so a requester's event on it emails nobody.
# - Each email is sent from this job and recorded in UserNotification in the same transaction
#   (see send_once), so a record means the email really went out, and a retry never sends a second one.
# - With a notice kind (KIND_OTHER_CHOSEN or KIND_AVAILABLE_AGAIN) it instead emails the requesters
#   of `request_ids`, the item's other open requests, about what the event did to their chances.
class RequestEventNotificationJob < ApplicationJob
  queue_as :default

  # The mail server being briefly unreachable. Retrying is safe: emails already sent are recorded
  # and skipped.
  retry_on Net::OpenTimeout, Net::ReadTimeout, Net::SMTPServerBusy, Errno::ECONNREFUSED, Errno::ECONNRESET,
    wait: :polynomially_longer, attempts: 5

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
      # Once per wish, not per event: recorded on the item.
      send_once(recipient, request.item, UserNotification::KIND_WISHLIST_AVAILABLE) do
        WishlistMailer.wishlist_available(recipient, request.item, request)
      end
    when "requested"
      send_once(recipient, event, UserNotification::KIND_REQUEST_EVENT) { ItemRequestMailer.new_request_notification(request) }
    else
      send_once(recipient, event, UserNotification::KIND_REQUEST_EVENT) { RequestEventMailer.event_update(event, recipient) }
    end
  end

  def send_item_notices(event, kind, request_ids)
    # Only requests still waiting: one declined or cancelled since then needs no notice.
    ItemRequest.where(id: request_ids).awaiting_decision.includes(:requester).find_each do |request|
      next if request.requester_id == event.user_id
      send_once(request.requester, event, kind) { RequestEventMailer.item_notice(kind, request, event) }
    end
  end

  # Sends the mail the block builds, unless `user` was already sent this one. The record and the
  # send share a transaction: if sending fails, the record rolls back and the job fails, so a retry
  # sends it. The unique index on the record stops a second or parallel run from sending it again.
  def send_once(user, notifiable, kind)
    UserNotification.transaction do
      UserNotification.create!(user: user, notifiable: notifiable, kind: kind, sent_at: Time.current)
      yield.deliver_now
    end
  rescue ActiveRecord::RecordNotUnique
    nil
  end
end
