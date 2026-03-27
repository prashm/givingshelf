require "test_helper"

class GrowthStatsServiceTest < ActiveSupport::TestCase
  setup do
    @previous_cache = Rails.cache
    Rails.cache = ActiveSupport::Cache::MemoryStore.new
    GrowthStat.delete_all
  end

  teardown do
    Rails.cache = @previous_cache
  end

  test "recalculate_global_landing! does not persist rows when raw counts are below min_value" do
    GrowthStatsService.recalculate_global_landing!
    assert_equal 0, GrowthStat.global.for_type(LandingGrowthStats::STAT_TYPE).count

    payload = GrowthStatsService.landing_payload
    assert_equal LandingGrowthStats.names, payload[:stats].map { |s| s[:id] }
    payload[:stats].each do |stat|
      assert_equal "0+", stat[:value], "expected placeholder for #{stat[:id]}"
      assert_equal LandingGrowthStats.display_name(stat[:id]), stat[:label]
    end
  end

  test "recalculate_global_landing! persists rows when use_min_value is false" do
    GrowthStatsService.recalculate_global_landing!(false)

    rows = GrowthStat.global.for_type(LandingGrowthStats::STAT_TYPE).order(:stat_name)
    assert_equal 3, rows.count

    expected = {
      "groups_created" => "#{CommunityGroup.where.not(short_name: [ CommunityGroup::ZIPCODE_SHORT_NAME, CommunityGroup::GROUP_ADMINS_SHORT_NAME ]).count}+",
      "items_shared" => "#{Item.where(type: [ Book.name, Toy.name ]).count}+",
      "local_givers" => "#{User.joins(:items).distinct.count}+"
    }

    rows.each do |row|
      assert_equal expected[row.stat_name], row.stat_value
    end
  end

  test "recalculate_global_landing! persists rows when raw counts meet min_value" do
    LandingGrowthStats.stub(:min_value_for, ->(_name) { 0 }) do
      GrowthStatsService.recalculate_global_landing!
    end

    rows = GrowthStat.global.for_type(LandingGrowthStats::STAT_TYPE).order(:stat_name)
    assert_equal 3, rows.count

    expected = {
      "groups_created" => "#{CommunityGroup.where.not(short_name: [ CommunityGroup::ZIPCODE_SHORT_NAME, CommunityGroup::GROUP_ADMINS_SHORT_NAME ]).count}+",
      "items_shared" => "#{Item.where(type: [ Book.name, Toy.name ]).count}+",
      "local_givers" => "#{User.joins(:items).distinct.count}+"
    }
    rows.each do |row|
      assert_equal expected[row.stat_name], row.stat_value, "unexpected value for #{row.stat_name}"
    end

    payload = GrowthStatsService.landing_payload
    LandingGrowthStats.names.each do |name|
      stat = payload[:stats].find { |s| s[:id] == name }
      assert_equal expected[name], stat[:value]
      assert_equal LandingGrowthStats.display_name(name), stat[:label]
    end
  end

  test "landing_payload serves from cache when present" do
    LandingGrowthStats.stub(:min_value_for, ->(_name) { 0 }) do
      GrowthStatsService.recalculate_global_landing!
    end
    GrowthStat.delete_all

    payload = GrowthStatsService.landing_payload
    assert_equal "2+", payload[:stats].find { |s| s[:id] == "local_givers" }[:value]
  end
end
