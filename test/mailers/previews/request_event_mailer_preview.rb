# Preview at http://localhost:3000/rails/mailers/request_event_mailer (GS-11).
# Uses the first request in the database and unsaved events, so nothing is written.
class RequestEventMailerPreview < ActionMailer::Preview
  def accepted = event_update(ItemRequest::ACCEPTED_STATUS, owner, "Pick up Saturday after 10?")
  def declined = event_update(ItemRequest::DECLINED_STATUS, owner, "Sorry, I promised it to a neighbour.")
  def closed_out = event_update(ItemRequest::DECLINED_STATUS, owner, ItemRequestService::CLOSE_OUT_DECLINED_NOTE)
  def item_removed = event_update(ItemRequest::DECLINED_STATUS, owner, ItemRequestService.note_after(ItemRequestService::ITEM_REMOVED_NOTE, "It got water damaged."))
  def moved = event_update(ItemRequest::PENDING_STATUS, owner, ItemRequestService::CLOSE_OUT_MOVED_NOTE)
  def moved_after_removal = event_update(ItemRequest::PENDING_STATUS, owner, ItemRequestService.note_after(ItemRequestService::ITEM_REMOVED_MOVED_NOTE, "Lost it, sorry."))
  def completed = event_update(ItemRequest::COMPLETED_STATUS, owner, "Enjoy!")
  def cancelled = event_update(ItemRequest::CANCELLED_STATUS, request.requester, "Found a copy at the library.", recipient: owner)
  def reopened = event_update(ItemRequest::PENDING_STATUS, request.requester, nil, recipient: owner)

  def other_chosen = RequestEventMailer.item_notice(UserNotification::KIND_OTHER_CHOSEN, request, nil)
  def available_again = RequestEventMailer.item_notice(UserNotification::KIND_AVAILABLE_AGAIN, request, nil)

  private

  def request = @request ||= ItemRequest.where.not(owner_id: nil).first
  def owner = request.owner

  def event_update(status, author, note, recipient: request.requester)
    event = request.messages.build(user: author, request_transition_status: status, content: note)
    RequestEventMailer.event_update(event, recipient)
  end
end
