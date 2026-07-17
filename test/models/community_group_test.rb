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

  test "support_item_types defaults to nil meaning all types" do
    group = community_groups(:one)
    assert_nil group.support_item_types
    assert group.supports_all_item_types?
    assert_nil group.restricted_item_type
  end

  test "support_item_types accepts B and T" do
    group = community_groups(:one)
    group.support_item_types = "B"
    assert group.valid?
    assert_equal "Book", group.restricted_item_type
    assert_not group.supports_all_item_types?

    group.support_item_types = "T"
    assert group.valid?
    assert_equal "Toy", group.restricted_item_type
  end

  test "support_item_types rejects unknown codes" do
    group = community_groups(:one)
    group.support_item_types = "X"
    assert_not group.valid?
    assert group.errors[:support_item_types].any?
  end

  test "blank support_item_types is normalized to nil" do
    group = community_groups(:one)
    group.support_item_types = ""
    group.valid?
    assert_nil group.support_item_types
  end
end
