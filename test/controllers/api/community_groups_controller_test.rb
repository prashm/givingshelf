require "test_helper"

class Api::CommunityGroupsControllerTest < ActionDispatch::IntegrationTest
  def json
    JSON.parse(response.body)
  end

  def create_user!(email: "user_#{SecureRandom.hex(6)}@example.com")
    User.create!(
      email_address: email,
      password_digest: BCrypt::Password.create("password123!"),
      verified: true
    )
  end

  test "by_short_name returns group json when group exists" do
    get "/api/community_groups/by_short_name/#{community_groups(:one).short_name}"
    assert_response :success

    body = json
    assert_equal community_groups(:one).id, body["id"]
    assert_equal community_groups(:one).short_name, body["short_name"]
    assert_equal community_groups(:one).group_description, body["group_description"]
  end

  test "by_short_name returns 404 when group does not exist" do
    get "/api/community_groups/by_short_name/does-not-exist"
    assert_response :not_found
    assert_equal "Group not found", json["error"]
  end

  test "index returns only public groups" do
    CommunityGroup.update_all(public: false)
    community_groups(:one).update!(public: true)

    get "/api/community_groups", params: { q: "Test" }
    assert_response :success

    body = json
    assert_equal 1, body.length
    assert_equal community_groups(:one).id, body.first["id"]
  end

  test "index includes member_count" do
    group = community_groups(:one)
    group.update!(public: true)

    get "/api/community_groups", params: { q: group.name }
    assert_response :success

    row = json.find { |g| g["id"] == group.id }
    assert row, "Expected search result for group"
    assert row["member_count"].is_a?(Integer)
    assert_equal group.community_group_memberships.count, row["member_count"]
  end

  test "index filters by q against name (case-insensitive)" do
    CommunityGroup.update_all(public: false)
    community_groups(:one).update!(public: true)
    community_groups(:two).update!(public: true)

    get "/api/community_groups", params: { q: "test" }
    assert_response :success

    ids = json.map { |g| g["id"] }
    assert_includes ids, community_groups(:one).id
    assert_not_includes ids, community_groups(:two).id
  end

  test "index filters by q against short_name (case-insensitive)" do
    CommunityGroup.update_all(public: false)
    community_groups(:one).update!(public: true)
    community_groups(:two).update!(public: true)

    get "/api/community_groups", params: { q: "ANOTHER-GROUP" }
    assert_response :success

    ids = json.map { |g| g["id"] }
    assert_includes ids, community_groups(:two).id
    assert_not_includes ids, community_groups(:one).id
  end

  test "index with blank q returns public groups" do
    CommunityGroup.update_all(public: false)
    community_groups(:one).update!(public: true)
    community_groups(:two).update!(public: true)

    get "/api/community_groups", params: { q: "   " }
    assert_response :success

    ids = json.map { |g| g["id"] }
    assert_includes ids, community_groups(:one).id
    assert_includes ids, community_groups(:two).id
  end

  test "show returns details for private group" do
    group = community_groups(:one)
    group.update!(public: false)

    get "/api/community_groups/#{group.id}"
    assert_response :success
    assert_equal group.id, json["id"]
  end

  test "show returns membership_state none when unauthenticated" do
    group = community_groups(:one)
    group.update!(public: true)

    get "/api/community_groups/#{group.id}"
    assert_response :success
    assert_equal "none", json["membership_state"]
    assert_equal group.community_group_memberships.count, json["member_count"]
  end

  test "show returns membership_state member when user is a member" do
    group = community_groups(:one)
    group.update!(public: true)
    user = users(:two) # fixture user already member of group one

    sign_in_as(user)
    get "/api/community_groups/#{group.id}"
    assert_response :success
    assert_equal "member", json["membership_state"]
  end

  test "show returns membership_state requested when join request exists" do
    group = community_groups(:two)
    group.update!(public: true)
    user = create_user!
    sign_in_as(user)

    GroupMembershipRequest.create!(
      community_group: group,
      requester: user,
      requester_type: "User",
      status: GroupMemberStatus::REQUESTED
    )

    get "/api/community_groups/#{group.id}"
    assert_response :success
    assert_equal "requested", json["membership_state"]
  end

  test "show returns membership_state invited when invite exists" do
    group = community_groups(:two)
    group.update!(public: true)
    user = create_user!(email: "invitee@example.com")
    sign_in_as(user)

    GroupMembershipRequest.create!(
      community_group: group,
      requester: users(:one),
      requester_type: "Admin",
      status: GroupMemberStatus::INVITED,
      email_address: user.email_address
    )

    get "/api/community_groups/#{group.id}"
    assert_response :success
    assert_equal "invited", json["membership_state"]
  end

  test "request_to_join requires authentication" do
    group = community_groups(:one)
    group.update!(public: true)

    post "/api/community_groups/#{group.id}/request_to_join", params: { message: "hi" }
    assert_response :unauthorized
  end

  test "request_to_join creates a Requested group_membership_request and enqueues mail" do
    group = community_groups(:one)
    group.update!(public: true)
    user = create_user!(email: "new_user@example.com")

    sign_in_as(user)

    delivery = Minitest::Mock.new
    delivery.expect(:deliver_later, true)
    CommunityGroupMailer.stub(:join_request, delivery) do
      post "/api/community_groups/#{group.id}/request_to_join", params: { message: "Please add me" }
    end
    delivery.verify

    assert_response :created
    req = GroupMembershipRequest.last
    assert_equal group.id, req.community_group_id
    assert_equal user.id, req.requester_id
    assert_equal "User", req.requester_type
    assert_equal GroupMemberStatus::REQUESTED, req.status
    assert_equal "Please add me", req.message
  end

  test "request_to_join returns 404 when group is not public" do
    group = community_groups(:one)
    group.update!(public: false)
    user = create_user!
    sign_in_as(user)

    post "/api/community_groups/#{group.id}/request_to_join"
    assert_response :not_found
  end

  test "request_to_join is idempotent when already a member" do
    group = community_groups(:one)
    group.update!(public: true)
    user = users(:two) # already a member of group one
    sign_in_as(user)

    CommunityGroupMailer.stub(:join_request, ->(*) { flunk("should not email for already_member") }) do
      post "/api/community_groups/#{group.id}/request_to_join", params: { message: "ignored" }
    end
    assert_response :unprocessable_entity
    assert_equal "already a member", json["error"]
  end

  test "request_to_join is idempotent when already requested" do
    group = community_groups(:two)
    group.update!(public: true)
    user = create_user!
    sign_in_as(user)

    GroupMembershipRequest.create!(
      community_group: group,
      requester: user,
      requester_type: "User",
      status: GroupMemberStatus::REQUESTED
    )

    CommunityGroupMailer.stub(:join_request, ->(*) { flunk("should not email for already_requested") }) do
      post "/api/community_groups/#{group.id}/request_to_join"
    end
    assert_response :unprocessable_entity
    assert_equal "already requested", json["error"]
  end

  test "my_groups requires authentication" do
    get "/api/my_groups"
    assert_response :unauthorized
  end

  test "my_groups returns only current user's memberships" do
    user = users(:one)
    sign_in_as(user)

    get "/api/my_groups"
    assert_response :success

    ids = json.map { |g| g["membership_id"] }
    assert ids.all?
    assert_equal user.community_group_memberships.count, ids.length
  end

  test "my_group_requests returns only requested requests for current user" do
    user = create_user!
    sign_in_as(user)

    mine = GroupMembershipRequest.create!(
      community_group: community_groups(:one),
      requester: user,
      requester_type: "User",
      status: GroupMemberStatus::REQUESTED,
      message: "please"
    )
    GroupMembershipRequest.create!(
      community_group: community_groups(:one),
      requester: users(:one),
      requester_type: "User",
      status: GroupMemberStatus::REQUESTED
    )
    GroupMembershipRequest.create!(
      community_group: community_groups(:one),
      requester: user,
      requester_type: "Admin",
      status: GroupMemberStatus::INVITED,
      email_address: user.email_address
    )

    get "/api/my_groups/requests"
    assert_response :success

    body = json
    assert_equal 1, body.length
    assert_equal mine.id, body.first["id"]
  end

  test "my_group_invites returns only invites matching current user's email" do
    user = create_user!(email: "invited@example.com")
    sign_in_as(user)

    mine = GroupMembershipRequest.create!(
      community_group: community_groups(:one),
      requester: users(:one),
      requester_type: "Admin",
      status: GroupMemberStatus::INVITED,
      email_address: user.email_address,
      message: "join us"
    )
    GroupMembershipRequest.create!(
      community_group: community_groups(:one),
      requester: users(:one),
      requester_type: "Admin",
      status: GroupMemberStatus::INVITED,
      email_address: "someone_else@example.com"
    )

    get "/api/my_groups/invites"
    assert_response :success

    body = json
    assert_equal 1, body.length
    assert_equal mine.id, body.first["id"]
    assert body.first["inviter"]
  end

  test "accept_invite requires authentication" do
    post "/api/my_groups/invites/123/accept"
    assert_response :unauthorized
  end

  test "accept_invite returns 404 when request does not exist" do
    sign_in_as(users(:one))
    post "/api/my_groups/invites/999999/accept"
    assert_response :not_found
  end

  test "accept_invite returns 403 when invite email does not match" do
    group = community_groups(:one)
    invitee = create_user!(email: "right@example.com")
    other = create_user!(email: "wrong@example.com")

    req = GroupMembershipRequest.create!(
      community_group: group,
      requester: users(:one),
      requester_type: "Admin",
      status: GroupMemberStatus::INVITED,
      email_address: invitee.email_address
    )

    sign_in_as(other)
    post "/api/my_groups/invites/#{req.id}/accept"
    assert_response :forbidden
  end

  test "accept_invite returns already_member when user already belongs to group. Sets request to accepted." do
    group = community_groups(:one)
    user = users(:two) # already member of group one

    req = GroupMembershipRequest.create!(
      community_group: group,
      requester: users(:one),
      requester_type: "Admin",
      status: GroupMemberStatus::INVITED,
      email_address: user.email_address
    )

    sign_in_as(user)
    post "/api/my_groups/invites/#{req.id}/accept"
    assert_response :unprocessable_entity
    assert_equal "already a member", json["error"]
    assert_equal GroupMemberStatus::ACCEPTED, req.reload.status
  end

  test "accept_invite creates membership and marks request accepted" do
    group = community_groups(:two)
    invitee = create_user!(email: "acceptme@example.com")

    req = GroupMembershipRequest.create!(
      community_group: group,
      requester: users(:one),
      requester_type: "Admin",
      status: GroupMemberStatus::INVITED,
      email_address: invitee.email_address
    )

    sign_in_as(invitee)
    assert_difference "CommunityGroupMembership.count", 1 do
      delivery = Minitest::Mock.new
      delivery.expect(:deliver_later, true)
      CommunityGroupMailer.stub(:invite_accepted, delivery) do
        post "/api/my_groups/invites/#{req.id}/accept"
      end
      delivery.verify
    end
    assert_response :success
    assert_equal "accepted", json["status"]
    assert_equal GroupMemberStatus::ACCEPTED, req.reload.status
    assert req.accepted_at
    assert req.responded_at
  end

  test "leave_group requires authentication" do
    delete "/api/my_groups/memberships/123"
    assert_response :unauthorized
  end

  test "leave_group deletes membership" do
    user = users(:one)
    membership = community_group_memberships(:three) # belongs to user one
    sign_in_as(user)

    assert_difference "CommunityGroupMembership.count", -1 do
      delete "/api/my_groups/memberships/#{membership.id}"
    end
    assert_response :success
    assert_equal "left", json["status"]
  end

  test "leave_group returns 422 when leaving ZIP Code Community group" do
    user = users(:one)
    sign_in_as(user)

    zip_group = CommunityGroup.find_or_create_zipcode_group!

    membership = CommunityGroupMembership.find_or_create_by!(user: user, community_group: zip_group) do |m|
      m.admin = false
      m.auto_joined = true
    end

    assert_no_difference "CommunityGroupMembership.count" do
      delete "/api/my_groups/memberships/#{membership.id}"
    end
    assert_response :unprocessable_entity
    assert json["errors"].join(" ").match?(/request not allowed/i)
  end

  test "leave_group returns 422 when user is sole admin of the group" do
    user = users(:one)
    membership = community_group_memberships(:one) # user one is admin of group one
    sign_in_as(user)

    assert membership.admin
    assert_equal 1, CommunityGroupMembership.admins.where(community_group_id: membership.community_group_id).count

    assert_no_difference "CommunityGroupMembership.count" do
      delete "/api/my_groups/memberships/#{membership.id}"
    end
    assert_response :unprocessable_entity
    assert json["errors"].join(" ").match?(/only admin/i)
  end

  test "update_membership updates sub_group for current user's membership" do
    user = users(:one)
    membership = community_group_memberships(:one) # user one member of group one
    sign_in_as(user)

    assert_nil membership.sub_group_id

    patch "/api/my_groups/memberships/#{membership.id}", params: { sub_group_id: sub_groups(:one).id }
    assert_response :success
    assert_equal "updated", json["status"]
    assert_equal sub_groups(:one).id, membership.reload.sub_group_id
  end

  test "update_membership returns 422 when sub_group does not belong to membership's group" do
    user = users(:one)
    membership = community_group_memberships(:one) # group one
    sign_in_as(user)

    # sub_groups(:three) belongs to group two
    patch "/api/my_groups/memberships/#{membership.id}", params: { sub_group_id: sub_groups(:three).id }
    assert_response :unprocessable_entity
    assert json["errors"].join(" ").match?(/must belong to the same community group/i)
  end

  test "leave_group returns 404 when membership is not owned by user" do
    user = users(:one)
    other_membership = community_group_memberships(:two) # belongs to user two
    sign_in_as(user)

    delete "/api/my_groups/memberships/#{other_membership.id}"
    assert_response :not_found
  end

  test "cancel_join_request requires authentication" do
    delete "/api/my_groups/requests/123"
    assert_response :unauthorized
  end

  test "cancel_join_request returns 403 when request does not belong to user" do
    user = create_user!
    other = create_user!
    req = GroupMembershipRequest.create!(
      community_group: community_groups(:one),
      requester: other,
      requester_type: "User",
      status: GroupMemberStatus::REQUESTED
    )

    sign_in_as(user)
    delete "/api/my_groups/requests/#{req.id}"
    assert_response :forbidden
  end

  test "cancel_join_request deletes request when owned and requested" do
    user = create_user!
    req = GroupMembershipRequest.create!(
      community_group: community_groups(:one),
      requester: user,
      requester_type: "User",
      status: GroupMemberStatus::REQUESTED
    )

    sign_in_as(user)
    assert_difference "GroupMembershipRequest.count", -1 do
      delete "/api/my_groups/requests/#{req.id}"
    end
    assert_response :success
    assert_equal "cancelled", json["status"]
  end
end
