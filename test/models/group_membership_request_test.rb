require "test_helper"

class GroupMembershipRequestTest < ActiveSupport::TestCase
  test "valid join request requires requester_type User" do
    req = GroupMembershipRequest.new(
      community_group: community_groups(:one),
      requester: users(:one),
      requester_type: "User",
      status: GroupMemberStatus::REQUESTED
    )
    assert req.valid?
  end

  test "invite requires requester_type Admin and email_address" do
    req = GroupMembershipRequest.new(
      community_group: community_groups(:one),
      requester: users(:one),
      requester_type: "Admin",
      status: GroupMemberStatus::INVITED,
      email_address: "invitee@example.com"
    )
    assert req.valid?
  end

  test "invite without email is invalid" do
    req = GroupMembershipRequest.new(
      community_group: community_groups(:one),
      requester: users(:one),
      requester_type: "Admin",
      status: GroupMemberStatus::INVITED
    )
    assert_not req.valid?
    assert_includes req.errors[:email_address].join(" "), "blank"
  end
end

