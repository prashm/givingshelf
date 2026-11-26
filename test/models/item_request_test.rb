require "test_helper"

class ItemRequestTest < ActiveSupport::TestCase
  test "status enum keeps the stored values" do
    assert_equal({ "pending" => 0, "accepted" => 1, "declined" => 2, "in_review" => 3, "completed" => 4, "cancelled" => 5 },
      ItemRequest.statuses)
  end

  test "transition events store the request status value" do
    request = item_requests(:one)
    event = request.messages.create!(user: request.requester, request_transition_status: :in_review)
    assert_equal "in_review", event.reload.request_transition_status
    assert_equal 3, Message.connection.select_value("SELECT request_transition_status FROM messages WHERE id = #{event.id}")
  end

  test "other_requests returns the item's other requests but not this one" do
    request = item_requests(:one)
    third_user = User.create!(email_address: "third_#{SecureRandom.hex(4)}@example.com", password_digest: BCrypt::Password.create("password123!"), verified: true)
    other = ItemRequest.create!(item: request.item, requester: third_user)

    assert_equal [ other.id ], request.other_requests.pluck(:id)
  end

  test "can_transition_to? follows the transition table" do
    request = item_requests(:one)
    assert request.can_transition_to?("accepted")
    assert_not request.can_transition_to?("completed")

    request.status = "declined"
    assert_not request.can_transition_to?("cancelled")

    request.status = "cancelled"
    assert request.can_transition_to?("pending")
    assert_not request.can_transition_to?("accepted")
  end

  test "guard_transition! names the move and the current status" do
    request = item_requests(:one)
    request.status = "accepted"
    assert_nil request.guard_transition!("completed")

    request.status = "in_review"
    error = assert_raises(RuntimeError) { request.guard_transition!("completed") }
    assert_equal "Cannot complete an in review request", error.message
  end

  test "status_label falls back to Pending for unknown statuses" do
    assert_equal "In Review", ItemRequest.status_label("in_review")
    assert_equal "Pending", ItemRequest.status_label(99)
  end

  test "message_thread_writable? is open while the request is live with an owner" do
    request = item_requests(:one)
    [ "pending", "in_review", "accepted" ].each do |status|
      request.status = status
      assert request.message_thread_writable?, ItemRequest.status_label(status)
    end
    [ "cancelled", "declined", "completed" ].each do |status|
      request.status = status
      assert_not request.message_thread_writable?, ItemRequest.status_label(status)
    end

    request.status = "pending"
    request.owner = nil
    assert_not request.message_thread_writable?, "an open wish has no one to message"
  end

  test "initial_message is the first PENDING event, looked up once" do
    request = item_requests(:one)
    request.messages.delete_all
    first = request.messages.create!(user: request.requester, request_transition_status: "pending", content: "Opening message")
    request.messages.create!(user: request.requester, request_transition_status: "cancelled")
    request.messages.create!(user: request.requester, request_transition_status: "pending", content: "Reopening")

    assert_equal first, request.initial_message
    ActiveRecord::Base.uncached { assert_no_queries { request.initial_message } }
  end

  test "initial_message is looked up again after a reload" do
    request = item_requests(:one)
    request.messages.delete_all
    assert_nil request.initial_message
    request.messages.create!(user: request.requester, request_transition_status: "pending", content: "Backfilled later")

    assert_nil request.initial_message, "memoized until reload"
    assert_equal "Backfilled later", request.reload.initial_message.content
  end
end
