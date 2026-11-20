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
end
