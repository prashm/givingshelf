require "test_helper"
require "minitest/mock"

module Group
  class MembershipsControllerTest < ActionDispatch::IntegrationTest
    def setup
      @group_admin_user = users(:one)
      @group_admin_user.update_column(:group_admin, true)
      @group = community_groups(:one)
    end

    test "GET index renders memberships page" do
      sign_in_as(@group_admin_user)
      get group_admin_memberships_path(@group)
      assert_response :success
      assert_includes response.body, "Manage Memberships: #{@group.name}"
    end

    test "POST promote_member promotes member to admin" do
      sign_in_as(@group_admin_user)
      membership = community_group_memberships(:two)
      membership.update!(admin: false)

      post promote_group_admin_membership_path(@group, membership_id: membership.id)
      assert_redirected_to group_admin_memberships_path(@group, tab: "current")
      assert_equal "Member promoted to admin.", flash[:notice]
      assert membership.reload.admin?
    end

    test "POST demote_member blocks demoting last admin" do
      sign_in_as(@group_admin_user)
      last_admin_membership = community_group_memberships(:one)
      assert last_admin_membership.admin?
      assert_equal 1, @group.community_group_memberships.admins.count

      post demote_group_admin_membership_path(@group, membership_id: last_admin_membership.id)
      assert_redirected_to group_admin_memberships_path(@group, tab: "current")
      assert_equal "You can't remove the last admin from the group.", flash[:alert]
      assert last_admin_membership.reload.admin?
    end

    test "DELETE revoke_membership blocks revoking last admin" do
      sign_in_as(@group_admin_user)
      last_admin_membership = community_group_memberships(:one)

      delete revoke_group_admin_membership_path(@group, membership_id: last_admin_membership.id)
      assert_redirected_to group_admin_memberships_path(@group, tab: "current")
      assert_equal "You can't revoke membership for the last admin.", flash[:alert]
      assert CommunityGroupMembership.exists?(last_admin_membership.id)
    end

    test "POST accept_membership_request sends membership accepted email" do
      sign_in_as(@group_admin_user)

      new_user = User.create!(
        email_address: "accepted_user_#{SecureRandom.hex(6)}@example.com",
        password_digest: BCrypt::Password.create("password123!"),
        verified: true
      )

      request = GroupMembershipRequest.create!(
        community_group: @group,
        requester: new_user,
        requester_type: "User",
        status: GroupMemberStatus::REQUESTED
      )

      delivery = Minitest::Mock.new
      delivery.expect(:deliver_later, true)

      CommunityGroupMailer.stub(:membership_accepted, delivery) do
        post accept_group_admin_membership_request_path(@group, request_id: request.id)
      end
      delivery.verify

      assert_redirected_to group_admin_memberships_path(@group, tab: "requested")
    end

    test "POST reject_membership_request rejects a requested join request" do
      sign_in_as(@group_admin_user)
      user = User.create!(
        email_address: "reject_request_user_#{SecureRandom.hex(6)}@example.com",
        password_digest: BCrypt::Password.create("password123!"),
        verified: true
      )
      request = GroupMembershipRequest.create!(
        community_group: @group,
        requester: user,
        requester_type: "User",
        status: GroupMemberStatus::REQUESTED
      )

      post reject_group_admin_membership_request_path(@group, request_id: request.id)
      assert_redirected_to group_admin_memberships_path(@group, tab: "requested")
      assert_equal "Request rejected.", flash[:notice]
      assert_equal GroupMemberStatus::REJECTED, request.reload.status
    end

    test "POST create_invite creates invite request and sends email" do
      sign_in_as(@group_admin_user)
      email = "invite_me_#{SecureRandom.hex(6)}@example.com"

      delivery = Minitest::Mock.new
      delivery.expect(:deliver_later, true)

      assert_difference "GroupMembershipRequest.count", 1 do
        CommunityGroupMailer.stub(:invite, delivery) do
          post invite_group_admin_membership_requests_path(@group), params: { email_address: email, message: "hello" }
        end
      end
      delivery.verify

      assert_redirected_to group_admin_memberships_path(@group, tab: "invites")
      assert_equal "Invitation created.", flash[:notice]
    end

    test "POST revoke_invite rejects an invited request" do
      sign_in_as(@group_admin_user)
      request = GroupMembershipRequest.create!(
        community_group: @group,
        requester: users(:one),
        requester_type: "Admin",
        status: GroupMemberStatus::INVITED,
        email_address: "revoke_me_#{SecureRandom.hex(6)}@example.com"
      )

      post revoke_invite_group_admin_membership_request_path(@group, request_id: request.id)
      assert_redirected_to group_admin_memberships_path(@group, tab: "invites")
      assert_equal "Invite revoked.", flash[:notice]
      assert_equal GroupMemberStatus::REJECTED, request.reload.status
    end

    test "GET index with invites tab excludes accepted invitations" do
      sign_in_as(@group_admin_user)

      # Create a pending invitation
      pending_email = "pending_invite_#{SecureRandom.hex(6)}@example.com"
      pending_request = GroupMembershipRequest.create!(
        community_group: @group,
        requester: @group_admin_user,
        requester_type: "Admin",
        status: GroupMemberStatus::INVITED,
        email_address: pending_email
      )

      # Create an accepted invitation
      accepted_email = "accepted_invite_#{SecureRandom.hex(6)}@example.com"
      accepted_user = User.create!(
        email_address: accepted_email,
        password_digest: BCrypt::Password.create("password123!"),
        verified: true
      )
      accepted_request = GroupMembershipRequest.create!(
        community_group: @group,
        requester: @group_admin_user,
        requester_type: "Admin",
        status: GroupMemberStatus::INVITED,
        email_address: accepted_email
      )

      # Accept the invitation by creating membership and updating status
      delivery = Minitest::Mock.new
      delivery.expect(:deliver_later, true)
      CommunityGroupMailer.stub(:invite_accepted, delivery) do
        CommunityGroupService.new(@group).add_user_to_group_from_request(accepted_user, accepted_request)
      end
      delivery.verify

      assert_equal GroupMemberStatus::ACCEPTED, accepted_request.reload.status

      # View the invites tab
      get group_admin_memberships_path(@group, tab: "invites")
      assert_response :success

      # Verify pending invitation appears
      assert_includes response.body, pending_email

      # Verify accepted invitation does NOT appear
      assert_not_includes response.body, accepted_email
    end
  end
end
