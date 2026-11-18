require "test_helper"

class GroupMembershipRequestTest < ActiveSupport::TestCase
  test "maps enum statuses to expected database integers and removes numeric constants from GroupMemberStatus" do
    expected = {
      "requested" => 0,
      "invited" => 1,
      "accepted" => 2,
      "rejected" => 3
    }
    assert_equal expected, GroupMembershipRequest.statuses

    %i[REQUESTED INVITED ACCEPTED REJECTED].each do |const_name|
      assert_not GroupMemberStatus.const_defined?(const_name), "Expected GroupMemberStatus::#{const_name} to be removed"
    end

    assert_equal GroupMembershipRequest.statuses.keys, GroupMemberStatus.values
    assert_equal(
      {
        "Requested" => GroupMembershipRequest.requested.new.status,
        "Invited" => GroupMembershipRequest.invited.new.status,
        "Accepted" => GroupMembershipRequest.accepted.new.status,
        "Rejected" => GroupMembershipRequest.rejected.new.status
      },
      GroupMemberStatus.collection
    )
    assert_equal "Requested", GroupMemberStatus.display_status(:requested)
    assert_equal "Invited", GroupMemberStatus.display_status(:invited)
    assert_equal "Accepted", GroupMemberStatus.display_status(:accepted)
    assert_equal "Rejected", GroupMemberStatus.display_status(:rejected)
    assert_equal "Unknown", GroupMemberStatus.display_status(:unknown)
  end

  test "defaults to requested and supports scopes, predicates, transitions, accept, reject, and db integer values" do
    user = User.create!(
      email_address: "gmr_enum_#{SecureRandom.hex(4)}@example.com",
      password_digest: BCrypt::Password.create("password123!"),
      verified: true
    )
    req = GroupMembershipRequest.create!(
      community_group: community_groups(:two),
      requester: user,
      requester_type: "User"
    )

    assert req.requested?
    assert_equal "Requested", req.display_status
    assert_includes GroupMembershipRequest.requested, req
    assert_not_includes GroupMembershipRequest.not_requested, req
    assert_equal 0, req.reload.read_attribute_before_type_cast(:status)

    assert req.accept
    assert req.reload.accepted?
    assert_equal "Accepted", req.display_status
    assert_not_nil req.accepted_at
    assert_not_nil req.responded_at
    assert_includes GroupMembershipRequest.accepted, req
    assert_equal 2, req.read_attribute_before_type_cast(:status)

    assert req.reject
    assert req.reload.rejected?
    assert_equal "Rejected", req.display_status
    assert_includes GroupMembershipRequest.rejected, req
    assert_equal 3, req.read_attribute_before_type_cast(:status)

    invite = GroupMembershipRequest.invited.create!(
      community_group: community_groups(:two),
      requester: users(:one),
      requester_type: "Admin",
      email_address: "invitee_enum_#{SecureRandom.hex(4)}@example.com"
    )
    assert invite.invited?
    assert_equal "Invited", invite.display_status
    assert_includes GroupMembershipRequest.invited, invite
    assert_equal 1, invite.reload.read_attribute_before_type_cast(:status)
  end

  test "valid join request requires requester_type User" do
    req = GroupMembershipRequest.requested.new(
      community_group: community_groups(:one),
      requester: users(:one),
      requester_type: "User"
    )
    assert req.valid?

    invalid_req = GroupMembershipRequest.requested.new(
      community_group: community_groups(:one),
      requester: users(:one),
      requester_type: "Admin"
    )
    assert_not invalid_req.valid?
    assert_not_empty invalid_req.errors[:requester_type]
  end

  test "invite requires requester_type Admin and email_address" do
    req = GroupMembershipRequest.invited.new(
      community_group: community_groups(:one),
      requester: users(:one),
      requester_type: "Admin",
      email_address: "invitee@example.com"
    )
    assert req.valid?
  end

  test "invite without email is invalid" do
    req = GroupMembershipRequest.invited.new(
      community_group: community_groups(:one),
      requester: users(:one),
      requester_type: "Admin"
    )
    assert_not req.valid?
    assert_includes req.errors[:email_address].join(" "), "blank"
  end

  test "rejects invalid status values" do
    req = GroupMembershipRequest.new(
      community_group: community_groups(:one),
      requester: users(:one),
      requester_type: "User",
      status: "not_a_status"
    )
    assert_not req.valid?
    assert_not_empty req.errors[:status]
  end
end
