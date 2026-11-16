require "test_helper"

class ItemRequestTest < ActiveSupport::TestCase
  test "maps enum statuses to expected database integers and removes *_STATUS constants" do
    expected = {
      "pending" => 0,
      "accepted" => 1,
      "declined" => 2,
      "in_review" => 3,
      "completed" => 4,
      "cancelled" => 5
    }
    assert_equal expected, ItemRequest.statuses

    %i[
      PENDING_STATUS
      ACCEPTED_STATUS
      DECLINED_STATUS
      IN_REVIEW_STATUS
      COMPLETED_STATUS
      CANCELLED_STATUS
    ].each do |const_name|
      assert_not ItemRequest.const_defined?(const_name), "Expected ItemRequest::#{const_name} to be removed"
    end
  end

  test "defaults to pending and supports scopes, predicates, and db integer values" do
    book = items(:two)
    ItemRequest.where(item: book, requester: users(:one)).destroy_all

    req = ItemRequest.create!(
      item: book,
      requester: users(:one),
      message: "I would love to read this book if it is still available."
    )
    assert_equal "pending", req.status
    assert req.pending?
    assert_includes ItemRequest.pending, req
    assert_equal 0, req.reload.read_attribute_before_type_cast(:status)

    {
      accepted: 1,
      declined: 2,
      in_review: 3,
      completed: 4,
      cancelled: 5
    }.each do |status_name, db_int|
      req.public_send("#{status_name}!")
      assert_equal status_name.to_s, req.status
      assert req.public_send("#{status_name}?")
      assert_includes ItemRequest.public_send(status_name), req
      assert_equal db_int, req.reload.read_attribute_before_type_cast(:status)
    end
  end

  test "can_update_status? respects cancelled and accepted sibling requests" do
    req = item_requests(:one)
    req.pending!
    assert req.can_update_status?

    other_user = User.create!(
      email_address: "other_req_#{SecureRandom.hex(4)}@example.com",
      password_digest: BCrypt::Password.create("password123!"),
      verified: true
    )
    sibling = ItemRequest.create!(
      item: req.item,
      requester: other_user,
      owner: req.owner,
      message: "Another valid request message for testing.",
      status: :accepted
    )

    assert sibling.can_update_status?
    assert_not req.can_update_status?

    sibling.cancelled!
    assert_not sibling.can_update_status?
    assert req.can_update_status?
  end

  test "rejects invalid status values" do
    req = ItemRequest.new(
      item: items(:two),
      requester: users(:one),
      message: "Valid request message here.",
      status: "not_a_status"
    )
    assert_not req.valid?
    assert_not_empty req.errors[:status]
  end
end
