namespace :sitemap do
  desc "Generate sitemap"
  task refresh: :environment do
    require "sitemap_generator"
    SitemapGenerator::Sitemap.verbose = true
    # Loading the config file will execute the SitemapGenerator::Sitemap.create block
    load Rails.root.join("config", "sitemap.rb")
    puts "Sitemap generated successfully!"
  end
end

