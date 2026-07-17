require "test_helper"

class SupportItemTypeTest < ActiveSupport::TestCase
  test "values excludes nil (all types)" do
    assert_equal [ "B", "T" ], SupportItemType.values
  end

  test "label_for returns friendly names" do
    assert_equal "Books and Toys", SupportItemType.label_for(nil)
    assert_equal "Books Only", SupportItemType.label_for("B")
    assert_equal "Toys Only", SupportItemType.label_for("T")
  end

  test "item_class_for maps codes to STI class names" do
    assert_nil SupportItemType.item_class_for(nil)
    assert_equal "Book", SupportItemType.item_class_for("B")
    assert_equal "Toy", SupportItemType.item_class_for("T")
  end

  test "collection_for_select includes all options" do
    collection = SupportItemType.collection_for_select
    assert_includes collection, [ "Books and Toys", nil ]
    assert_includes collection, [ "Books Only", "B" ]
    assert_includes collection, [ "Toys Only", "T" ]
  end
end
