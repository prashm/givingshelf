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
