require "test_helper"

# GS-11: what each status-change email says.
class RequestEventMailerTest < ActionMailer::TestCase
  def setup
    @request = item_requests(:one) # users(:two) asked users(:one) for items(:one)
    @owner = @request.owner
    @requester = @request.requester
    @title = @request.item.title
  end

  def event(status, author, content = nil)
    @request.messages.create!(user: author, request_transition_status: status, content: content)
  end

  def body(mail) = mail.body.to_s

  test "an accept goes to the requester, with the owner's note and a link to the request" do
    mail = RequestEventMailer.event_update(event(ItemRequest::ACCEPTED_STATUS, @owner, "Pick up Saturday?"), @requester)

    assert_equal [ @requester.email_address ], mail.to
    assert_equal "Good news: #{@title} is yours", mail.subject
    assert_includes body(mail), "accepted your request"
    assert_includes body(mail), "Pick up Saturday?"
    assert_includes body(mail), "item_request_details?id=#{@request.id}"
  end

  test "each event kind has its own subject" do
    {
      [ ItemRequest::DECLINED_STATUS, @owner, nil ] => "Update on your request for #{@title}",
      [ ItemRequest::DECLINED_STATUS, @owner, ItemRequestService::CLOSE_OUT_DECLINED_NOTE ] => "#{@title} went to another requester",
      [ ItemRequest::PENDING_STATUS, @owner, ItemRequestService::CLOSE_OUT_MOVED_NOTE ] => "#{@title} went to another requester, and your wish is still listed",
      [ ItemRequest::COMPLETED_STATUS, @owner, nil ] => "Enjoy #{@title}!"
    }.each do |(status, author, content), subject|
      assert_equal subject, RequestEventMailer.event_update(event(status, author, content), @requester).subject
    end
    cancelled = RequestEventMailer.event_update(event(ItemRequest::CANCELLED_STATUS, @requester, "Found one"), @owner)
    assert_equal [ @owner.email_address ], cancelled.to
    assert_equal "#{@requester.display_name} cancelled their request for #{@title}", cancelled.subject
  end

  test "a close-out email shows only the person's own note, not the fixed text again" do
    removed = event(ItemRequest::DECLINED_STATUS, @owner, ItemRequestService.note_after(ItemRequestService::ITEM_REMOVED_NOTE, "It got water damaged."))
    mail = RequestEventMailer.event_update(removed, @requester)

    assert_equal "#{@title} was removed by its owner", mail.subject
    assert_includes body(mail), "It got water damaged."
    assert_not_includes body(mail), ItemRequestService::ITEM_REMOVED_NOTE

    plain = RequestEventMailer.event_update(event(ItemRequest::DECLINED_STATUS, @owner, ItemRequestService::CLOSE_OUT_DECLINED_NOTE), @requester)
    assert_not_includes body(plain), "&ldquo;"
  end

  test "a wisher moved after the donor removed their copy is told so" do
    moved = event(ItemRequest::PENDING_STATUS, @owner, ItemRequestService.note_after(ItemRequestService::ITEM_REMOVED_MOVED_NOTE, "Lost it"))
    mail = RequestEventMailer.event_update(moved, @requester)
    assert_equal "The donor removed their copy of #{@title}, and your wish is still listed", mail.subject
  end

  test "the notices to other requesters" do
    chosen = RequestEventMailer.item_notice(UserNotification::KIND_OTHER_CHOSEN, @request, nil)
    assert_equal [ @requester.email_address ], chosen.to
    assert_equal "Someone else was chosen for #{@title}", chosen.subject
    assert_includes body(chosen), "they can still choose you"

    again = RequestEventMailer.item_notice(UserNotification::KIND_AVAILABLE_AGAIN, @request, nil)
    assert_equal "#{@title} is available again", again.subject
  end
end
