require "test_helper"

class ToyAgeRangeTest < ActiveSupport::TestCase
  test "display_age_range returns label for known value" do
    assert_equal "5-7 years", ToyAgeRange.display_age_range("5-7 years")
  end

  test "display_age_range returns raw value for unknown value" do
    assert_equal "8+", ToyAgeRange.display_age_range("8+")
  end

  test "parse returns bounds and trimmed label for open-ended input" do
    parsed = ToyAgeRange.parse("  8+ ")
    assert_equal({ min: 8, max: nil, label: "8+" }, parsed)
  end

  test "parse handles explicit ranges" do
    assert_equal({ min: 5, max: 7, label: "5-7 years" }, ToyAgeRange.parse("5-7 years"))
    assert_equal({ min: 3, max: 6, label: "3-6" }, ToyAgeRange.parse("3-6"))
  end

  test "parse maps known aliases" do
    assert_equal({ min: 0, max: 2 }, ToyAgeRange.parse("toddler").slice(:min, :max))
    assert_equal({ min: 13, max: nil }, ToyAgeRange.parse("teen").slice(:min, :max))
  end

  test "parse handles bare numbers and canonical buckets" do
    assert_equal({ min: 8, max: 10, label: "8-10 years" }, ToyAgeRange.parse("8-10 years"))
    assert_equal({ min: 6, max: 6, label: "6" }, ToyAgeRange.parse("6"))
  end

  test "parse returns nil for unrecognized input" do
    assert_nil ToyAgeRange.parse("unknown gibberish")
    assert_nil ToyAgeRange.parse("")
    assert_nil ToyAgeRange.parse(nil)
  end

  test "bucket_bounds returns bounds for canonical values" do
    assert_equal({ min: 8, max: 10 }, ToyAgeRange.bucket_bounds("8-10 years"))
    assert_equal({ min: 13, max: nil }, ToyAgeRange.bucket_bounds("13+ years"))
    assert_nil ToyAgeRange.bucket_bounds("not a bucket")
  end

  test "matching_buckets returns every overlapping bucket" do
    assert_equal [ "8-10 years", "11-12 years", "13+ years" ], ToyAgeRange.matching_buckets(8, nil)
    assert_equal [ "5-7 years" ], ToyAgeRange.matching_buckets(5, 7)
    assert_equal [], ToyAgeRange.matching_buckets(nil, nil)
  end

  test "accepted_inputs exposes labels, examples, and patterns" do
    metadata = ToyAgeRange.accepted_inputs
    assert_equal ToyAgeRange.values, metadata[:bucket_labels]
    assert_includes metadata[:examples], "8+"
    assert metadata[:patterns].all? { |p| p.key?(:label) && p.key?(:regex) }
  end
end
