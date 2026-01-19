require "test_helper"
require "ostruct"

module Group
  class AdminControllerTest < ActionDispatch::IntegrationTest
    def setup
      @group_admin_user = users(:one)
      @group_admin_user.update_column(:group_admin, true) # Set group_admin flag
    end

    # new action tests
    test "GET new renders login page when not authenticated" do
      get group_admin_login_path
      assert_response :success
    end

    test "GET new redirects to index when authenticated as group admin" do
      sign_in_as(@group_admin_user)
      get group_admin_login_path
      assert_redirected_to group_admin_index_path
    end

    # create action tests (login)
    test "POST create succeeds with valid credentials and group admin user" do
      # Mock User.authenticate_by to return the user
      User.stub(:authenticate_by, @group_admin_user) do
        post group_admin_login_path, params: {
          email: @group_admin_user.email_address,
          password: "password"
        }
      end

      assert_redirected_to group_admin_index_path
      assert_equal "Signed in successfully.", flash[:notice]
    end

    test "POST create fails with blank email" do
      post group_admin_login_path, params: {
        email: "",
        password: "password"
      }

      assert_response :unprocessable_entity
      assert_equal "Email and password are required.", flash[:alert]
    end

    test "POST create fails with blank password" do
      post group_admin_login_path, params: {
        email: @group_admin_user.email_address,
        password: ""
      }

      assert_response :unprocessable_entity
      assert_equal "Email and password are required.", flash[:alert]
    end

    test "POST create fails with invalid credentials" do
      User.stub(:authenticate_by, nil) do
        post group_admin_login_path, params: {
          email: "wrong@example.com",
          password: "wrongpassword"
        }
      end

      assert_response :unprocessable_entity
      assert_equal "Invalid email or password, or you don't have group admin access.", flash[:alert]
    end

    test "POST create fails when user is not group admin" do
      non_admin_user = OpenStruct.new(email_address: "nonadmin@example.com", group_admin: false)

      User.stub(:authenticate_by, non_admin_user) do
        post group_admin_login_path, params: {
          email: non_admin_user.email_address,
          password: "password"
        }
      end

      assert_response :unprocessable_entity
      assert_equal "Invalid email or password, or you don't have group admin access.", flash[:alert]
    end

    # destroy action tests (logout)
    test "DELETE destroy logs out successfully" do
      sign_in_as(@group_admin_user)

      delete group_admin_logout_path

      assert_redirected_to group_admin_login_path
      assert_equal "Signed out successfully.", flash[:notice]
    end
  end
end
