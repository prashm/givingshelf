require "test_helper"

class HomeGrowthStatsTest < ActionDispatch::IntegrationTest
  setup do
    @previous_cache = Rails.cache
    Rails.cache = ActiveSupport::Cache::MemoryStore.new
    GrowthStat.delete_all
    GrowthStatsService.recalculate_global_landing!
  end

  teardown do
    Rails.cache = @previous_cache
  end

  test "GET /growth_stats returns stats array" do
    get "/growth_stats"
    assert_response :success
    body = JSON.parse(response.body)
    assert_kind_of Array, body["stats"]
    assert_equal 3, body["stats"].size
    ids = body["stats"].map { |s| s["id"] }.sort
    assert_equal %w[groups_created items_shared local_givers], ids
  end
end
