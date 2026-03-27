namespace :growth_stats do
  desc "Recalculate global landing growth stats and warm Rails.cache (Solid Cache in production)"
  task recalculate: :environment do
    GrowthStatsService.recalculate_global_landing!
    puts "Growth stats recalculated and cache warmed."
  end
end
