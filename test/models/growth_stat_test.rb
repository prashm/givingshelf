require "test_helper"

class GrowthStatTest < ActiveSupport::TestCase
  test "duplicate global stat_type and stat_name violates uniqueness" do
    GrowthStat.create!(
      stat_type: "growth_stat_test_global",
      stat_name: "metric_a",
      stat_value: "1+",
      computed_at: Time.current
    )
    assert_raises(ActiveRecord::RecordNotUnique) do
      GrowthStat.create!(
        stat_type: "growth_stat_test_global",
        stat_name: "metric_a",
        stat_value: "2+",
        computed_at: Time.current
      )
    end
  end

  test "same stat_name allowed for different community groups" do
    group = community_groups(:one)
    other = community_groups(:two)
    GrowthStat.create!(
      stat_type: "growth_stat_test_per_group",
      stat_name: "members",
      stat_value: "1+",
      community_group: group,
      computed_at: Time.current
    )
    assert_nothing_raised do
      GrowthStat.create!(
        stat_type: "growth_stat_test_per_group",
        stat_name: "members",
        stat_value: "5+",
        community_group: other,
        computed_at: Time.current
      )
    end
  end
end
