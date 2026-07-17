require "test_helper"

class SiteContextAndGroupRulesTest < ActionDispatch::IntegrationTest
  def json
    JSON.parse(response.body)
  end

  def create_user!(email:)
    User.create!(
      email_address: email,
      password_digest: BCrypt::Password.create("password123!"),
      verified: true
    )
  end

  setup do
    # Path/header group resolution only applies on local dev hosts
    host! ApplicationSite.domain
  end

  test "site_context returns null host_group on apex without header" do
    get "/api/site_context"
    assert_response :success

    body = json
    assert_nil body["host_group"]
    assert_equal "none", body["url_mode"]
    assert_nil body["rules"]["email_domain_required"]
    assert_equal false, body["rules"]["restrict_join_other_groups"]
  end

  test "site_context resolves group from X-Site-Group-Short-Name header on localhost" do
    group = community_groups(:one)

    get "/api/site_context", headers: { "X-Site-Group-Short-Name" => group.short_name }
    assert_response :success

    body = json
    assert_equal group.id, body["host_group"]["id"]
    assert_equal group.short_name, body["host_group"]["short_name"]
    assert_equal group.domain, body["rules"]["email_domain_required"]
    assert_equal true, body["rules"]["restrict_join_other_groups"]
    assert_equal "path", body["url_mode"]
  end

  test "login rejects email that does not match group domain from header" do
    group = community_groups(:one)

    post "/api/login",
         params: { email: "outsider@other.com" },
         headers: { "X-Site-Group-Short-Name" => group.short_name },
         as: :json

    assert_response :unprocessable_entity
    assert_match(/@#{Regexp.escape(group.domain)}/, json["error"])
  end

  test "login accepts email that matches group domain from header" do
    group = community_groups(:one)
    email = "member@#{group.domain}"

    post "/api/login",
         params: { email: email },
         headers: { "X-Site-Group-Short-Name" => group.short_name },
         as: :json

    assert_response :created
    assert_equal true, json["requires_otp"]
  end

  test "request_to_join is forbidden when user belongs to a domain-locked group" do
    locked = community_groups(:one)
    locked.update!(public: true, domain: "locked.edu")

    other = community_groups(:two)
    other.update!(public: true, domain: nil)

    user = create_user!(email: "alice@locked.edu")
    unless user.community_group_memberships.exists?(community_group: locked)
      CommunityGroupMembership.create!(user: user, community_group: locked, admin: false, auto_joined: true)
    end
    sign_in_as(user)

    post "/api/community_groups/#{other.id}/request_to_join", params: { message: "hi" }, as: :json
    assert_response :forbidden
    assert_match(/organization group|cannot join/i, json["error"])
  end

  test "request_to_join is forbidden for other groups when site header sets a group" do
    site_group = community_groups(:one)
    site_group.update!(public: true)

    other = community_groups(:two)
    other.update!(public: true, domain: nil)

    user = create_user!(email: "bob@example.com")
    sign_in_as(user)

    post "/api/community_groups/#{other.id}/request_to_join",
         params: { message: "hi" },
         headers: { "X-Site-Group-Short-Name" => site_group.short_name },
         as: :json

    assert_response :forbidden
    assert_match(/only join/i, json["error"])
  end

  test "request_to_join allowed for the site group itself" do
    site_group = community_groups(:one)
    site_group.update!(public: true, domain: nil)

    user = create_user!(email: "carol@example.com")
    sign_in_as(user)

    assert_difference -> { GroupMembershipRequest.count }, 1 do
      post "/api/community_groups/#{site_group.id}/request_to_join",
           params: { message: "please" },
           headers: { "X-Site-Group-Short-Name" => site_group.short_name },
           as: :json
    end

    assert_response :created
  end
end
