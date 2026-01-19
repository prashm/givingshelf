require "test_helper"
require "ostruct"
require "minitest/mock"

module Group
  class GroupsControllerTest < ActionDispatch::IntegrationTest
    def setup
      @group_admin_user = users(:one)
      @group_admin_user.update_column(:group_admin, true) # Set group_admin flag

      # Use a real ActiveRecord group so form_with(model: ...) works
      @mock_group = community_groups(:one)
    end

    # Helper to stub admin_community_groups on all User instances
    # This is needed because Current.user might be a different instance than @group_admin_user
    def stub_admin_community_groups_for_all_users(mock_association)
      original = User.instance_method(:admin_community_groups)
      User.define_method(:admin_community_groups) { mock_association }
      yield
    ensure
      User.define_method(:admin_community_groups, original)
    end

    # index action tests
    test "GET index succeeds for authenticated group admin" do
      sign_in_as(@group_admin_user)

      # Mock admin_community_groups with method chaining
      mock_association = Minitest::Mock.new
      mock_association.expect(:includes, mock_association, [ :sub_groups, :community_group_memberships ])
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
      assert_redirected_to group_admin_login_path
    end

    # show action tests
    test "GET show succeeds for authenticated group admin with valid group" do
      sign_in_as(@group_admin_user)

      # Mock admin_community_groups.find to return mock group
      mock_association = Minitest::Mock.new
      mock_association.expect(:find, @mock_group, [ @mock_group.id.to_s ])

      stub_admin_community_groups_for_all_users(mock_association) do
        get group_admin_path(@mock_group.id)
      end

      assert_response :success
      mock_association.verify
    end

    test "GET show redirects when group not found" do
      sign_in_as(@group_admin_user)

      # Mock admin_community_groups.find to raise RecordNotFound
      mock_association = Minitest::Mock.new
      mock_association.expect(:find, nil) { |_id| raise ActiveRecord::RecordNotFound }

      stub_admin_community_groups_for_all_users(mock_association) do
        get group_admin_path(999)
      end

      assert_redirected_to group_admin_index_path
      assert_equal "Group not found.", flash[:alert]
    end

    def request_params_for_group(name)
      {
        name: name,
        group_description: "community",
        domain: "newgroup.com",
        short_name: "new-group"
      }.with_indifferent_access
    end

    # create action tests
    test "POST create succeeds when service creates group" do
      sign_in_as(@group_admin_user)
      expected_params = request_params_for_group("New Group")
      mock_service = Minitest::Mock.new
      mock_service.expect(:create_group, @mock_group, [ @group_admin_user, expected_params ])

      CommunityGroupService.stub(:new, mock_service) do
        post group_admin_index_path, params: {
          community_group: expected_params
        }
      end

      assert_redirected_to group_admin_path(@mock_group.id)
      assert_equal "Group created successfully.", flash[:notice]
      mock_service.verify
    end

    test "POST create fails when service returns nil" do
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
          patch group_admin_path(@mock_group.id), params: {
            community_group: expected_params
          }
        end
      end

      assert_redirected_to group_admin_path(@mock_group.id)
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
          patch group_admin_path(@mock_group.id), params: {
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
          post sub_groups_group_admin_path(@mock_group.id), params: {
            name: expected_name
          }
        end
      end

      assert_redirected_to group_admin_path(@mock_group.id)
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
          post sub_groups_group_admin_path(@mock_group.id), params: {
            name: ""
          }
        end
      end

      assert_redirected_to group_admin_path(@mock_group.id)
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
          delete sub_group_group_admin_path(@mock_group.id, sub_group_id: 1)
        end
      end

      assert_redirected_to group_admin_path(@mock_group.id)
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
          delete sub_group_group_admin_path(@mock_group.id, sub_group_id: 999)
        end
      end

      assert_redirected_to group_admin_path(@mock_group.id)
      assert_equal "Couldn't find SubGroup", flash[:alert]
      mock_service.verify
      mock_association.verify
    end

    # destroy action tests
    test "DELETE destroy redirects with notice when group deleted" do
      sign_in_as(@group_admin_user)
      group = community_groups(:one)

      mock_service = Minitest::Mock.new
      mock_service.expect(:delete_group, true)

      CommunityGroupService.stub(:new, mock_service) do
        delete group_admin_path(group)
      end

      assert_redirected_to group_admin_index_path
      assert_equal "Group deleted successfully.", flash[:notice]
      mock_service.verify
    end

    test "DELETE destroy redirects with alert when service fails" do
      sign_in_as(@group_admin_user)
      group = community_groups(:one)

      mock_service = Minitest::Mock.new
      mock_service.expect(:delete_group, false)
      mock_service.expect(:errors, [ "Nope" ])

      CommunityGroupService.stub(:new, mock_service) do
        delete group_admin_path(group)
      end

      assert_redirected_to group_admin_index_path
      assert_equal "Nope", flash[:alert]
      mock_service.verify
    end
  end
end

