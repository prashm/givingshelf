# Preview at http://localhost:3000/rails/mailers/request_event_mailer (GS-11).
# Uses the first request in the database and unsaved events, so nothing is written.
class RequestEventMailerPreview < ActionMailer::Preview
  def accepted = event_update(:accepted, owner, "Pick up Saturday after 10?")
  def declined = event_update(:declined, owner, "Sorry, I promised it to a neighbour.")
  def closed_out = event_update(:declined, owner, ItemRequestService::CLOSE_OUT_DECLINED_NOTE)
  def item_removed = event_update(:declined, owner, ItemRequestService.note_after(ItemRequestService::ITEM_REMOVED_NOTE, "It got water damaged."))
  def moved = event_update(:pending, owner, ItemRequestService::CLOSE_OUT_MOVED_NOTE)
  def moved_after_removal = event_update(:pending, owner, ItemRequestService.note_after(ItemRequestService::ITEM_REMOVED_MOVED_NOTE, "Lost it, sorry."))
  def completed = event_update(:completed, owner, "Enjoy!")
  def cancelled = event_update(:cancelled, request.requester, "Found a copy at the library.", recipient: owner)
  def reopened = event_update(:pending, request.requester, nil, recipient: owner)

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
