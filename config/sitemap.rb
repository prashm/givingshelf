# Set the host name for URL generation
SitemapGenerator::Sitemap.default_host = "https://booksharecommunity.org"

# Set the sitemap path
SitemapGenerator::Sitemap.public_path = "public/"

# Set the sitemap path on the server
SitemapGenerator::Sitemap.sitemaps_path = "sitemaps/"

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

