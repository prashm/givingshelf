require "test_helper"

class ItemRequestTest < ActiveSupport::TestCase
  test "other_requests returns the item's other requests but not this one" do
    request = item_requests(:one)
    third_user = User.create!(email_address: "third_#{SecureRandom.hex(4)}@example.com", password_digest: BCrypt::Password.create("password123!"), verified: true)
    other = ItemRequest.create!(item: request.item, requester: third_user)

    assert_equal [ other.id ], request.other_requests.pluck(:id)
  end

  test "can_transition_to? follows the transition table" do
    request = item_requests(:one)
    assert request.can_transition_to?(ItemRequest::ACCEPTED_STATUS)
    assert_not request.can_transition_to?(ItemRequest::COMPLETED_STATUS)

    request.status = ItemRequest::DECLINED_STATUS
    assert_not request.can_transition_to?(ItemRequest::CANCELLED_STATUS)

    request.status = ItemRequest::CANCELLED_STATUS
    assert request.can_transition_to?(ItemRequest::PENDING_STATUS)
    assert_not request.can_transition_to?(ItemRequest::ACCEPTED_STATUS)
  end

  test "guard_transition! names the move and the current status" do
    request = item_requests(:one)
    request.status = ItemRequest::ACCEPTED_STATUS
    assert_nil request.guard_transition!(ItemRequest::COMPLETED_STATUS)

    request.status = ItemRequest::IN_REVIEW_STATUS
    error = assert_raises(RuntimeError) { request.guard_transition!(ItemRequest::COMPLETED_STATUS) }
    assert_equal "Cannot complete an in review request", error.message
  end

  test "status_label falls back to Pending for unknown statuses" do
    assert_equal "In Review", ItemRequest.status_label(ItemRequest::IN_REVIEW_STATUS)
    assert_equal "Pending", ItemRequest.status_label(99)
  end

  test "message_thread_writable? is open while the request is live with an owner" do
    request = item_requests(:one)
    [ ItemRequest::PENDING_STATUS, ItemRequest::IN_REVIEW_STATUS, ItemRequest::ACCEPTED_STATUS ].each do |status|
      request.status = status
      assert request.message_thread_writable?, ItemRequest.status_label(status)
    end
    [ ItemRequest::CANCELLED_STATUS, ItemRequest::DECLINED_STATUS, ItemRequest::COMPLETED_STATUS ].each do |status|
      request.status = status
      assert_not request.message_thread_writable?, ItemRequest.status_label(status)
    end

    request.status = ItemRequest::PENDING_STATUS
    request.owner = nil
    assert_not request.message_thread_writable?, "an open wish has no one to message"
  end

  test "initial_message is the first PENDING event, looked up once" do
    request = item_requests(:one)
    request.messages.delete_all
    first = request.messages.create!(user: request.requester, request_transition_status: ItemRequest::PENDING_STATUS, content: "Opening message")
    request.messages.create!(user: request.requester, request_transition_status: ItemRequest::CANCELLED_STATUS)
    request.messages.create!(user: request.requester, request_transition_status: ItemRequest::PENDING_STATUS, content: "Reopening")

    assert_equal first, request.initial_message
    ActiveRecord::Base.uncached { assert_no_queries { request.initial_message } }
  end

  test "initial_message is looked up again after a reload" do
    request = item_requests(:one)
    request.messages.delete_all
    assert_nil request.initial_message
    request.messages.create!(user: request.requester, request_transition_status: ItemRequest::PENDING_STATUS, content: "Backfilled later")

    assert_nil request.initial_message, "memoized until reload"
    assert_equal "Backfilled later", request.reload.initial_message.content
  end
end
