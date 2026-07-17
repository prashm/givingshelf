# Set the host name for URL generation
SitemapGenerator::Sitemap.default_host = ApplicationSite.base_url

# Set the sitemap path
SitemapGenerator::Sitemap.public_path = "public/"

# Generate sitemap directly in public/ (not in a subdirectory)
# This matches the robots.txt reference to /sitemap.xml

# Generate sitemap
SitemapGenerator::Sitemap.create do
  # Add homepage
  add "/", priority: 1.0, changefreq: "daily"

  # Add all available books
  Book.available.find_each do |book|
    add "/books/#{book.id}",
        lastmod: book.updated_at,
        priority: 0.8,
        changefreq: "weekly"
  end

  # Add all available toys
  Toy.available.find_each do |toy|
    add "/toys/#{toy.id}",
        lastmod: toy.updated_at,
        priority: 0.8,
        changefreq: "weekly"
  end

  # Group landing / browse pages on subdomains
  CommunityGroup.where.not(short_name: [
    CommunityGroup::ZIPCODE_SHORT_NAME,
    CommunityGroup::GROUP_ADMINS_SHORT_NAME
  ]).find_each do |group|
    next if CommunityGroup::RESERVED_SHORT_NAMES.include?(group.short_name)

    base = ApplicationSite.subdomain_url(group.short_name).delete_suffix("/")
    add "#{base}/",
        lastmod: group.updated_at,
        priority: 0.7,
        changefreq: "weekly"
    add "#{base}/books",
        lastmod: group.updated_at,
        priority: 0.6,
        changefreq: "weekly"
    add "#{base}/toys",
        lastmod: group.updated_at,
        priority: 0.6,
        changefreq: "weekly"
  end
end
