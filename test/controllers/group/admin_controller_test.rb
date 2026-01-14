require "test_helper"
require "ostruct"
require "minitest/mock"

module Group
  class AdminControllerTest < ActionDispatch::IntegrationTest
    def setup
      @group_admin_user = users(:one)
      @group_admin_user.update_column(:group_admin, true) # Set group_admin flag

      # Mock group object
      @mock_group = OpenStruct.new(id: 1, name: "Test Group", domain: "test.com", short_name: "test-group", sub_groups: [])
    end

    # Helper to stub admin_community_groups on all User instances
    # This is needed because Current.user might be a different instance than @group_admin_user
    def stub_admin_community_groups_for_all_users(mock_association)
      # Temporarily redefine the method to return our mock
      # Note: This redefines the association method for all User instances during the test
      User.define_method(:admin_community_groups) do
        mock_association
      end

      yield
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

    # index action tests
    test "GET index succeeds for authenticated group admin" do
      sign_in_as(@group_admin_user)

      # Mock admin_community_groups with method chaining
      mock_association = Minitest::Mock.new
      mock_association.expect(:includes, mock_association, [ :sub_groups ])
      # order is called with keyword arguments: order(created_at: :desc)
      # In Minitest::Mock, keyword args are passed as the 4th parameter
      mock_association.expect(:order, [], [], created_at: :desc)

      stub_admin_community_groups_for_all_users(mock_association) do
        get group_admin_index_path
      end

      assert_response :success
      mock_association.verify
    end

    test "GET index redirects when not authenticated" do
      get group_admin_index_path
      # require_authentication redirects first, so ensure_group_admin is never called
      assert_redirected_to group_admin_login_path
    end

    # show action tests
    test "GET show succeeds for authenticated group admin with valid group" do
      sign_in_as(@group_admin_user)

      # Mock admin_community_groups.find to return mock group
      mock_association = Minitest::Mock.new
      mock_association.expect(:find, @mock_group, [ @mock_group.id.to_s ])

      stub_admin_community_groups_for_all_users(mock_association) do
        get group_admin_group_path(@mock_group.id)
      end

      assert_response :success
      mock_association.verify
    end

    test "GET show redirects when group not found" do
      sign_in_as(@group_admin_user)

      # Mock admin_community_groups.find to raise RecordNotFound
      mock_association = Minitest::Mock.new
      mock_association.expect(:find, nil) { |id| raise ActiveRecord::RecordNotFound }

      stub_admin_community_groups_for_all_users(mock_association) do
        get group_admin_group_path(999)
      end

      assert_redirected_to group_admin_index_path
      assert_equal "Group not found.", flash[:alert]
    end

    def request_params_for_group(name)
      {
        name: name,
        group_type: "community",
        domain: "newgroup.com",
        short_name: "new-group"
      }.with_indifferent_access
    end

    # create_group action tests
    test "POST create_group succeeds when service creates group" do
      sign_in_as(@group_admin_user)
      expected_params = request_params_for_group("New Group")
      mock_service = Minitest::Mock.new
      mock_service.expect(:create_group, @mock_group, [ @group_admin_user, expected_params ])

      CommunityGroupService.stub(:new, mock_service) do
        post group_admin_index_path, params: {
          community_group: expected_params
        }
      end

      assert_redirected_to group_admin_group_path(@mock_group.id)
      assert_equal "Group created successfully.", flash[:notice]
      mock_service.verify
    end

    test "POST create_group fails when service returns nil" do
      sign_in_as(@group_admin_user)
      expected_params = request_params_for_group("")
      mock_service = Minitest::Mock.new
      mock_service.expect(:create_group, nil, [ @group_admin_user, expected_params ])
      mock_service.expect(:errors, [ "Name can't be blank" ])

      CommunityGroupService.stub(:new, mock_service) do
        post group_admin_index_path, params: {
          community_group: expected_params
        }
      end

      assert_redirected_to group_admin_index_path
      assert_equal "Name can't be blank", flash[:alert]
      mock_service.verify
    end

    # update action tests
    test "PATCH update succeeds when service updates group" do
      sign_in_as(@group_admin_user)
      expected_params = request_params_for_group("Updated Group Name")
      mock_service = Minitest::Mock.new
      mock_service.expect(:update_group, true, [ expected_params ])

      mock_association = Minitest::Mock.new
      mock_association.expect(:find, @mock_group, [ @mock_group.id.to_s ])

      stub_admin_community_groups_for_all_users(mock_association) do
        CommunityGroupService.stub(:new, mock_service) do
          patch group_admin_group_path(@mock_group.id), params: {
            community_group: expected_params
          }
        end
      end

      assert_redirected_to group_admin_group_path(@mock_group.id)
      assert_equal "Group updated successfully.", flash[:notice]
      mock_service.verify
      mock_association.verify
    end

    test "PATCH update fails when service returns false" do
      sign_in_as(@group_admin_user)
      expected_params = request_params_for_group("")

      mock_service = Minitest::Mock.new
      mock_service.expect(:update_group, false, [ expected_params ])
      mock_service.expect(:errors, [ "Name can't be blank" ])

      mock_association = Minitest::Mock.new
      mock_association.expect(:find, @mock_group, [ @mock_group.id.to_s ])

      stub_admin_community_groups_for_all_users(mock_association) do
        CommunityGroupService.stub(:new, mock_service) do
          patch group_admin_group_path(@mock_group.id), params: {
            community_group: expected_params
          }
        end
      end

      assert_response :unprocessable_entity
      assert_equal "Name can't be blank", flash[:alert]
      mock_service.verify
      mock_association.verify
    end

    # create_sub_group action tests
    test "POST create_sub_group succeeds when service adds sub group" do
      sign_in_as(@group_admin_user)
      expected_name = "Sub Group 1"
      mock_sub_group = OpenStruct.new(id: 1, name: "Sub Group 1")
      mock_service = Minitest::Mock.new
      mock_service.expect(:add_sub_group, mock_sub_group, [ expected_name ])

      mock_association = Minitest::Mock.new
      mock_association.expect(:find, @mock_group, [ @mock_group.id.to_s ])

      stub_admin_community_groups_for_all_users(mock_association) do
        CommunityGroupService.stub(:new, mock_service) do
          post group_admin_sub_groups_path(@mock_group.id), params: {
            name: expected_name
          }
        end
      end

      assert_redirected_to group_admin_group_path(@mock_group.id)
      assert_equal "Sub group added successfully.", flash[:notice]
      mock_service.verify
      mock_association.verify
    end

    test "POST create_sub_group fails when service returns nil" do
      sign_in_as(@group_admin_user)

      mock_service = Minitest::Mock.new
      mock_service.expect(:add_sub_group, nil, [ "" ])
      mock_service.expect(:errors, [ "Name can't be blank" ])

      mock_association = Minitest::Mock.new
      mock_association.expect(:find, @mock_group, [ @mock_group.id.to_s ])

      stub_admin_community_groups_for_all_users(mock_association) do
        CommunityGroupService.stub(:new, mock_service) do
          post group_admin_sub_groups_path(@mock_group.id), params: {
            name: ""
          }
        end
      end

      assert_redirected_to group_admin_group_path(@mock_group.id)
      assert_equal "Name can't be blank", flash[:alert]
      mock_service.verify
      mock_association.verify
    end

    # destroy_sub_group action tests
    test "DELETE destroy_sub_group succeeds when service removes sub group" do
      sign_in_as(@group_admin_user)

      mock_service = Minitest::Mock.new
      mock_service.expect(:remove_sub_group, true, [ 1 ])

      mock_association = Minitest::Mock.new
      mock_association.expect(:find, @mock_group, [ @mock_group.id.to_s ])

      stub_admin_community_groups_for_all_users(mock_association) do
        CommunityGroupService.stub(:new, mock_service) do
          delete group_admin_sub_group_path(@mock_group.id, 1)
        end
      end

      assert_redirected_to group_admin_group_path(@mock_group.id)
      assert_equal "Sub group removed successfully.", flash[:notice]
      mock_service.verify
      mock_association.verify
    end

    test "DELETE destroy_sub_group fails when service returns false" do
      sign_in_as(@group_admin_user)

      mock_service = Minitest::Mock.new
      mock_service.expect(:remove_sub_group, false, [ 999 ])
      mock_service.expect(:errors, [ "Couldn't find SubGroup" ])

      mock_association = Minitest::Mock.new
      mock_association.expect(:find, @mock_group, [ @mock_group.id.to_s ])

      stub_admin_community_groups_for_all_users(mock_association) do
        CommunityGroupService.stub(:new, mock_service) do
          delete group_admin_sub_group_path(@mock_group.id, 999)
        end
      end

      assert_redirected_to group_admin_group_path(@mock_group.id)
      assert_equal "Couldn't find SubGroup", flash[:alert]
      mock_service.verify
      mock_association.verify
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
