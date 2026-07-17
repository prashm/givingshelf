require "test_helper"

class CommunityGroupTest < ActiveSupport::TestCase
  test "rejects reserved short_name values" do
    CommunityGroup::RESERVED_SHORT_NAMES.each do |reserved|
      group = CommunityGroup.new(
        name: "Reserved #{reserved}",
        short_name: reserved,
        group_description: "test"
      )
      assert_not group.valid?, "Expected #{reserved} to be invalid"
      assert_includes group.errors[:short_name], "is reserved and cannot be used"
    end
  end

  test "allows non-reserved short_name" do
    group = CommunityGroup.new(
      name: "Valid Group",
      short_name: "acme-school",
      group_description: "test"
    )
    assert group.valid?
  end
end
