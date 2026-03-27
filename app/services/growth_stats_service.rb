class GrowthStatsService
  GLOBAL_LANDING_CACHE_KEY = "growth_stats/v1/#{LandingGrowthStats::STAT_TYPE}/global"
  CACHE_EXPIRES_IN = 14.days

  class << self
    def recalculate_global_landing!(use_min_value = true)
      now = Time.current
      LandingGrowthStats.names.each do |name|
        count = compute_landing_raw_count(name)
        if use_min_value
          min_value = LandingGrowthStats.min_value_for(name)
          next if count <= min_value
        end

        record = GrowthStat.find_or_initialize_by(
          stat_type: LandingGrowthStats::STAT_TYPE,
          stat_name: name,
          community_group_id: nil
        )
        record.stat_value = format_count_display(count)
        record.computed_at = now
        record.save!
      end
      write_landing_cache!
    end

    def landing_payload
      cached_json = Rails.cache.fetch(GLOBAL_LANDING_CACHE_KEY, expires_in: CACHE_EXPIRES_IN) do
        Rails.logger.info("GrowthStatsService: no growth_stats cache, using DB to build payload")
        JSON.generate(build_landing_payload_from_db)
      end

      JSON.parse(cached_json, symbolize_names: true)
    rescue JSON::ParserError
      Rails.logger.warn("GrowthStatsService: invalid growth_stats cache, using DB")
      build_landing_payload_from_db
    end

    private

    def write_landing_cache!
      payload = build_landing_payload_from_db
      Rails.cache.write(GLOBAL_LANDING_CACHE_KEY, JSON.generate(payload), expires_in: CACHE_EXPIRES_IN)
      payload
    end

    def build_landing_payload_from_db
      rows = GrowthStat.for_type(LandingGrowthStats::STAT_TYPE).global.index_by(&:stat_name)
      stats = LandingGrowthStats.names.map do |name|
        row = rows[name]
        {
          id: name,
          value: row&.stat_value || "0+",
          label: LandingGrowthStats.display_name(name)
        }
      end
      { stats: stats }
    end

    def compute_landing_raw_count(name)
      case name
      when LandingGrowthStats::LOCAL_GIVERS
        User.joins(:items).distinct.count
      when LandingGrowthStats::ITEMS_SHARED
        Item.where(type: [ Book.name, Toy.name ]).count
      when LandingGrowthStats::GROUPS_CREATED
        CommunityGroup.where.not(
          short_name: [ CommunityGroup::ZIPCODE_SHORT_NAME, CommunityGroup::GROUP_ADMINS_SHORT_NAME ]
        ).count
      else
        0
      end
    end

    def format_count_display(n)
      n = n.to_i
      n = 0 if n.negative?
      "#{n}+"
    end
  end
end
