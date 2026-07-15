require "test_helper"

class ToyTest < ActiveSupport::TestCase
  def toy
    items(:toy_one)
  end

  test "blank age_range is allowed and clears bounds" do
    toy.update!(age_range: "5-7 years")
    assert toy.update(age_range: "")
    assert_nil toy.reload.age_range
    assert_nil toy.min_age
    assert_nil toy.max_age
  end

  test "recognized age_range sets min and max on save" do
    assert toy.update(age_range: "8+")
    toy.reload
    assert_equal "8+", toy.age_range
    assert_equal 8, toy.min_age
    assert_nil toy.max_age
  end

  test "explicit range sets both bounds" do
    assert toy.update(age_range: "3-6 years")
    toy.reload
    assert_equal 3, toy.min_age
    assert_equal 6, toy.max_age
  end

  test "unrecognized age_range is rejected" do
    assert_not toy.update(age_range: "totally not an age")
    assert_includes toy.errors[:age_range], "is not recognized"
  end
end
