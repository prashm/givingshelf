# Set the host name for URL generation
SitemapGenerator::Sitemap.default_host = "https://givingshelf.net"

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
end
