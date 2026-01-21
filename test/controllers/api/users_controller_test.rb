require "test_helper"

class Api::UsersControllerTest < ActionDispatch::IntegrationTest
  test "should get show" do
    sign_in_as(users(:one))
    get api_user_url(users(:one))
    assert_response :success
  end

  test "should update user" do
    sign_in_as(users(:one))
    patch api_user_url(users(:one)), params: {
      user: {
        first_name: "Updated",
        last_name: "Name",
        zip_code: "12345"
      }
    }
    assert_response :success
  end

  test "updating zip code creates zipcode subgroup and assigns membership sub_group_id" do
    user = users(:one)
    sign_in_as(user)

    zip_group = CommunityGroup.find_or_create_zipcode_group!

    # Ensure clean slate
    CommunityGroupMembership.where(user: user, community_group: zip_group).delete_all
    SubGroup.where(community_group: zip_group, name: "99999").delete_all

    patch api_user_url(user), params: { user: { zip_code: "99999" } }
    assert_response :success

    sub_group = SubGroup.find_by!(community_group: zip_group, name: "99999")
    membership = CommunityGroupMembership.find_by!(user: user, community_group: zip_group)
    assert_equal sub_group.id, membership.sub_group_id
  end

  test "should get profile" do
    sign_in_as(users(:one))
    get profile_api_users_url
    assert_response :success
  end

  test "should get my_requests" do
    sign_in_as(users(:one))
    get my_requests_api_users_url
    assert_response :success
  end

  test "should get received_requests" do
    sign_in_as(users(:one))
    get received_requests_api_users_url
    assert_response :success
  end
end
