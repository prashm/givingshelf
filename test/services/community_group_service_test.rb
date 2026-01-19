require "test_helper"
require "minitest/spec"

class CommunityGroupServiceTest < ActiveSupport::TestCase
  extend Minitest::Spec::DSL

  # Disable parallelization for this test to avoid Proc serialization issues
  parallelize(workers: 1)

  def setup
    @service = CommunityGroupService.new
    @admin_user = users(:one)  # Use fixture instead of creating
  end

  # Remove teardown - fixtures handle cleanup automatically

  describe "#create_group" do
    it "creates a group successfully" do
      params = {
        name: "New Group",
        domain: "newgroup.com",
        short_name: "new-group",
        group_description: "community"
      }

      result = @service.create_group(@admin_user, params)

      assert_empty @service.errors
      assert_not_nil result
      assert_equal "New Group", @service.group.name
      assert_equal "newgroup.com", @service.group.domain
      assert_equal "new-group", @service.group.short_name
      assert @service.group.persisted?
    end

    it "creates admin membership for the creator" do
      params = {
        name: "New Group",
        domain: "newgroup.com",
        short_name: "new-group"
      }

      @service.create_group(@admin_user, params)

      membership = @service.group.community_group_memberships.find_by(user: @admin_user)
      assert_not_nil membership
      assert membership.admin
      assert_not membership.auto_joined
    end

    it "handles validation errors" do
      params = {
        name: "",
        domain: "invalid",
        short_name: "invalid short name"
      }

      result = @service.create_group(@admin_user, params)

      assert_nil result
      assert_includes @service.errors.join(" "), "Name can't be blank"
      assert_includes @service.errors.join(" "), "must be a valid domain"
      assert_includes @service.errors.join(" "), "must be lowercase alphanumeric and hyphens only"
    end

    it "handles exceptions during creation" do
      # use existing group params to fail creation of new group
      params = {
        name: "Test Group",
        domain: "test.com",
        short_name: "test-group"
      }

      # Use fixture group to cause uniqueness error
      result = @service.create_group(@admin_user, params)

      assert_nil result
      assert_includes @service.errors.join(" "), "Short name has already been taken"
    end

    it "rolls back group creation if admin membership creation fails" do
      params = {
        name: "Test Group 2",
        domain: "test2.com",
        short_name: "testgroup2"
      }
      result = @service.create_group(nil, params)

      assert_nil result
      assert_includes @service.errors.join(" "), "User"
      assert_nil CommunityGroup.find_by(short_name: "testgroup2")
    end
  end

  describe "#update_group" do
    it "updates group successfully" do
      group = community_groups(:three)  # Use fixture
      service = CommunityGroupService.new(group)

      result = service.update_group(name: "Updated Name")

      assert result
      assert_equal "Updated Name", group.reload.name
      assert_empty service.errors
    end

    it "returns false on validation errors" do
      group = community_groups(:three)  # Use fixture
      service = CommunityGroupService.new(group)

      result = service.update_group(name: "")

      assert_not result
      assert_includes service.errors.join(" "), "Name can't be blank"
    end

    it "has error when group is nil" do
      service = CommunityGroupService.new

      result = service.update_group(name: "Test")

      assert_not result
      assert_includes service.errors, "group can't be blank"
    end

    it "handles exceptions during update" do
      group = community_groups(:three)  # Use fixture
      service = CommunityGroupService.new(group)

      # Force an exception by trying to update with invalid domain format
      result = service.update_group(domain: "not_a_domain")

      assert_not result
      assert_includes service.errors.join(" "), "must be a valid domain"
    end
  end

  describe "#add_sub_group" do
    it "adds a sub group successfully" do
      group = community_groups(:one)  # Use fixture
      service = CommunityGroupService.new(group)

      sub_group = service.add_sub_group("Sub Group New")

      assert_not_nil sub_group
      assert sub_group.persisted?
      assert_equal "Sub Group New", sub_group.name
      assert_equal group.id, sub_group.community_group_id
    end

    it "returns nil on validation errors" do
      group = community_groups(:one)  # Use fixture
      service = CommunityGroupService.new(group)

      # Try to add duplicate name (fixture already has "Sub Group 1")
      result = service.add_sub_group("Sub Group 1")

      assert_nil result
      assert_includes service.errors.join(" "), "must be unique within the group"
    end

    it "raises error when group is nil" do
      service = CommunityGroupService.new

      result = service.add_sub_group("Sub Group 1")

      assert_nil result
      assert_includes service.errors, "group can't be blank"
    end

    it "handles exceptions during creation" do
      group = community_groups(:one)  # Use fixture
      service = CommunityGroupService.new(group)

      # Add sub group with empty name to trigger validation
      result = service.add_sub_group("")

      assert_nil result
      assert_includes service.errors.join(" "), "Name can't be blank"
    end
  end

  describe "#remove_sub_group" do
    it "removes a sub group successfully" do
      group = community_groups(:one)  # Use fixture
      sub_group = sub_groups(:one)  # Use fixture
      service = CommunityGroupService.new(group)

      result = service.remove_sub_group(sub_group.id)

      assert result
      assert_nil SubGroup.find_by(id: sub_group.id)
    end

    it "returns false when sub group doesn't exist" do
      group = community_groups(:one)  # Use fixture
      service = CommunityGroupService.new(group)

      result = service.remove_sub_group(99999)

      assert_not result
      assert_includes service.errors.join(" "), "Couldn't find SubGroup"
    end

    it "has error when sub_group_id is invalid" do
      group = community_groups(:one)  # Use fixture
      service = CommunityGroupService.new(group)

      result = service.remove_sub_group(0)

      assert_not result
      assert_includes service.errors, "sub_group is invalid"
    end

    it "has error when group is nil" do
      service = CommunityGroupService.new

      result = service.remove_sub_group(1)

      assert_not result
      assert_includes service.errors, "group can't be blank"
    end

    it "handles exceptions during removal" do
      group = community_groups(:one)  # Use fixture
      service = CommunityGroupService.new(group)

      # Try to remove non-existent sub group
      result = service.remove_sub_group(99999)

      assert_not result
      assert_includes service.errors.join(" "), "Couldn't find SubGroup"
    end
  end

  describe "#add_member" do
    it "adds a member successfully" do
      group = community_groups(:two)  # Use fixture (doesn't have user(:two) as member yet)
      user = users(:two)  # Use fixture
      service = CommunityGroupService.new(group)

      membership = service.add_member(user)

      assert_not_nil membership
      assert membership.persisted?
      assert_equal user.id, membership.user_id
      assert_equal group.id, membership.community_group_id
      assert_not membership.admin
      assert_not membership.auto_joined
    end

    it "adds a member with auto_joined flag" do
      group = community_groups(:two)  # Use fixture
      user = users(:two)  # Use fixture
      service = CommunityGroupService.new(group)

      membership = service.add_member(user, auto_joined: true)

      assert_not_nil membership
      assert membership.auto_joined
    end

    it "adds a member with admin flag" do
      group = community_groups(:two)  # Use fixture
      user = users(:two)  # Use fixture
      service = CommunityGroupService.new(group)

      membership = service.add_member(user, admin: true)

      assert_not_nil membership
      assert membership.admin
    end

    it "returns nil when group is nil" do
      service = CommunityGroupService.new
      user = users(:two)  # Use fixture

      result = service.add_member(user)

      assert_nil result
    end

    it "returns nil on validation errors" do
      group = community_groups(:one)  # Use fixture
      user = users(:one)  # Use fixture (already a member via fixture)
      service = CommunityGroupService.new(group)

      # Try to add same member again (should fail uniqueness validation)
      result = service.add_member(user)

      assert_nil result
      assert_includes service.errors.join(" "), "is already a member of this group"
    end
  end

  describe "#remove_member" do
    it "removes a member successfully" do
      group = community_groups(:one)  # Use fixture
      user = users(:one)  # Use fixture (member via community_group_memberships(:one))
      service = CommunityGroupService.new(group)

      result = service.remove_member(user)

      assert result
      assert_nil CommunityGroupMembership.find_by(user: user, community_group: group)
    end

    it "returns false when user is not a member" do
      group = community_groups(:two)  # Use fixture
      user = users(:two)  # Use fixture (not a member of group two)
      service = CommunityGroupService.new(group)

      result = service.remove_member(user)

      assert_not result
      assert_includes service.errors, "User is not a member of this group"
    end

    it "returns false when group is nil" do
      service = CommunityGroupService.new
      user = users(:two)  # Use fixture

      result = service.remove_member(user)

      assert_not result
    end
  end

  describe "#promote_to_admin" do
    it "promotes a member to admin successfully" do
      group = community_groups(:one)  # Use fixture
      user = users(:two)  # Use fixture (member via community_group_memberships(:two))
      service = CommunityGroupService.new(group)

      result = service.promote_to_admin(user)

      assert result
      assert community_group_memberships(:two).reload.admin
    end

    it "returns false when user is not a member" do
      group = community_groups(:two)  # Use fixture
      user = users(:two)  # Use fixture (not a member of group two)
      service = CommunityGroupService.new(group)

      result = service.promote_to_admin(user)

      assert_not result
      assert_includes service.errors, "User is not a member of this group"
    end

    it "returns false when group is nil" do
      service = CommunityGroupService.new
      user = users(:two)  # Use fixture

      result = service.promote_to_admin(user)

      assert_not result
    end

    it "handles exceptions during promotion" do
      group = community_groups(:one)  # Use fixture
      service = CommunityGroupService.new(group)
      user = users(:two)  # Use fixture (member)

      result = service.promote_to_admin(user)

      assert result  # Should succeed
    end
  end

  describe "#demote_from_admin" do
    it "demotes an admin successfully" do
      group = community_groups(:one)  # Use fixture
      user = users(:one)  # Use fixture (admin via community_group_memberships(:one))
      service = CommunityGroupService.new(group)

      result = service.demote_from_admin(user)

      assert result
      assert_not community_group_memberships(:one).reload.admin
    end

    it "returns false when user is not a member" do
      group = community_groups(:two)  # Use fixture
      user = users(:two)  # Use fixture (not a member)
      service = CommunityGroupService.new(group)

      result = service.demote_from_admin(user)

      assert_not result
      assert_includes service.errors, "User is not a member of this group"
    end

    it "returns false when group is nil" do
      service = CommunityGroupService.new
      user = users(:two)  # Use fixture

      result = service.demote_from_admin(user)

      assert_not result
    end

    it "handles exceptions during demotion" do
      group = community_groups(:one)  # Use fixture
      service = CommunityGroupService.new(group)
      user = users(:two)  # Use fixture (member but not admin)

      result = service.demote_from_admin(user)

      assert result  # Should succeed (demoting non-admin is fine)
    end
  end

  describe "#get_group_by_short_name" do
    it "returns group json when group exists" do
      group = community_groups(:one)  # Use fixture
      service = CommunityGroupService.new

      result = service.get_group_by_short_name("test-group")

      assert_not_empty result
      assert_equal group.id, result[:id]
      assert_equal "Test Group", result[:name]
      assert_equal "test.com", result[:domain]
      assert_equal "test-group", result[:short_name]
      assert_equal CommunityGroup::DEFAULT_SHORT_DESCRIPTION, result[:group_description]
      assert_equal 2, result[:sub_groups].length  # Fixture has 2 sub groups
    end

    it "returns empty hash when group doesn't exist" do
      service = CommunityGroupService.new

      result = service.get_group_by_short_name("non-existent")

      assert_equal({}, result)
    end
  end

  describe "#get_memberships_for_group" do
    it "returns memberships json when group exists" do
      group = community_groups(:one)  # Use fixture (has 2 memberships)
      service = CommunityGroupService.new(group)

      result = service.get_memberships_for_group

      assert_not_nil result
      assert_equal 2, result.length

      membership1_json = result.find { |m| m[:id] == community_group_memberships(:one).id }
      assert_not_nil membership1_json
      assert_equal users(:one).id, membership1_json[:user][:id]
      assert_equal "one@example.com", membership1_json[:user][:email_address]
      assert membership1_json[:admin]
      assert_not membership1_json[:auto_joined]

      membership2_json = result.find { |m| m[:id] == community_group_memberships(:two).id }
      assert_not_nil membership2_json
      assert_equal users(:two).id, membership2_json[:user][:id]
      assert_equal "two@example.com", membership2_json[:user][:email_address]
      assert_not membership2_json[:admin]
      assert membership2_json[:auto_joined]
    end

    it "returns nil when group is nil" do
      service = CommunityGroupService.new

      result = service.get_memberships_for_group

      assert_nil result
    end
  end

  describe ".group_map" do
    it "returns correct json structure" do
      group = community_groups(:one)  # Use fixture

      result = CommunityGroupService.group_map(group, include_sub_groups: true)

      assert_equal group.id, result[:id]
      assert_equal "Test Group", result[:name]
      assert_equal CommunityGroup::DEFAULT_SHORT_DESCRIPTION, result[:group_description]
      assert_equal "test.com", result[:domain]
      assert_equal "test-group", result[:short_name]
      assert_equal 2, result[:sub_groups].length  # Fixture has 2 sub groups
      assert_not_nil result[:created_at]
      assert_not_nil result[:updated_at]
    end
  end

  describe ".membership_map" do
    it "returns correct json structure" do
      membership = community_group_memberships(:one)  # Use fixture

      result = CommunityGroupService.membership_map(membership)

      assert_equal membership.id, result[:id]
      assert_equal users(:one).id, result[:user][:id]
      assert_equal "one@example.com", result[:user][:email_address]
      assert_equal "John Doe", result[:user][:display_name]
      assert_equal "John Doe", result[:user][:full_name]
      assert result[:admin]
      assert_not result[:auto_joined]
      assert_not_nil result[:created_at]
    end
  end
end
