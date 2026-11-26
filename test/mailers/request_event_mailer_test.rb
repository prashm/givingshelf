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
    mail = RequestEventMailer.event_update(event(:accepted, @owner, "Pick up Saturday?"), @requester)

    assert_equal [ @requester.email_address ], mail.to
    assert_includes body(mail), "accepted your request"
    assert_includes body(mail), "Pick up Saturday?"
    assert_includes body(mail), "item_request_details?id=#{@request.id}"
  end

  test "every email about a request has the same subject, worded for who gets it" do
    to_requester = "Update on your request for #{@request.item.type}: #{@title}"
    [
      [ :declined, nil ],
      [ :declined, ItemRequestService::CLOSE_OUT_DECLINED_NOTE ],
      [ :pending, ItemRequestService::CLOSE_OUT_MOVED_NOTE ],
      [ :completed, nil ]
    ].each do |status, content|
      assert_equal to_requester, RequestEventMailer.event_update(event(status, @owner, content), @requester).subject
    end
    assert_equal to_requester, RequestEventMailer.item_notice(UserNotification::KIND_OTHER_CHOSEN, @request, nil).subject

    cancelled = RequestEventMailer.event_update(event(:cancelled, @requester, "Found one"), @owner)
    assert_equal [ @owner.email_address ], cancelled.to
    assert_equal "Update on #{@requester.display_name}'s request for #{@request.item.type}: #{@title}", cancelled.subject
  end

  test "the first line says what changed" do
    {
      [ :declined, @owner, nil ] => "declined your request",
      [ :declined, @owner, ItemRequestService::CLOSE_OUT_DECLINED_NOTE ] => "was given to another requester",
      [ :pending, @owner, ItemRequestService::CLOSE_OUT_MOVED_NOTE ] => "went to another requester. You&#39;ve been moved",
      [ :completed, @owner, nil ] => "marked the handoff",
      [ :cancelled, @requester, nil ] => "cancelled their request"
    }.each do |(status, author, content), lead|
      recipient = author == @owner ? @requester : @owner
      assert_includes body(RequestEventMailer.event_update(event(status, author, content), recipient)), lead
    end
  end

  test "a close-out email shows only the person's own note, not the fixed text again" do
    removed = event(:declined, @owner, ItemRequestService.note_after(ItemRequestService::ITEM_REMOVED_NOTE, "It got water damaged."))
    mail = RequestEventMailer.event_update(removed, @requester)

    assert_includes body(mail), "so your request is closed"
    assert_includes body(mail), "It got water damaged."
    assert_not_includes body(mail), ItemRequestService::ITEM_REMOVED_NOTE

    plain = RequestEventMailer.event_update(event(:declined, @owner, ItemRequestService::CLOSE_OUT_DECLINED_NOTE), @requester)
    assert_not_includes body(plain), "&ldquo;"
  end

  test "a wisher moved after the donor removed their copy is told so" do
    moved = event(:pending, @owner, ItemRequestService.note_after(ItemRequestService::ITEM_REMOVED_MOVED_NOTE, "Lost it"))
    assert_includes body(RequestEventMailer.event_update(moved, @requester)), "The donor removed their copy"
  end

  test "the notices to other requesters" do
    chosen = RequestEventMailer.item_notice(UserNotification::KIND_OTHER_CHOSEN, @request, nil)
    assert_equal [ @requester.email_address ], chosen.to
    assert_includes body(chosen), "they can still choose you"

    again = RequestEventMailer.item_notice(UserNotification::KIND_AVAILABLE_AGAIN, @request, nil)
    assert_includes body(again), "available again"
  end
end
