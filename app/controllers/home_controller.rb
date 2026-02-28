class HomeController < ApplicationController
  allow_unauthenticated_access only: [ :index, :hero_images ]

  def index
    # Detect if this is an item detail page (/books/:id or /toys/:id)
    # Extract item from path for SEO meta tags
    @item = extract_item_from_path if request.format.html?

    respond_to do |format|
      format.html do
        # For HTML requests, render the React app
        render "index"
      end
      format.json do
        # For JSON requests, return a simple response or redirect to API
        render json: { message: "Please use /api/items for JSON requests" }, status: :not_acceptable
      end
    end
  end

  # Returns list of hero image filenames (hero-*.png, hero-*.jpg) for the landing page collage.
  # GET /hero_images
  def hero_images
    hero_dir = Rails.root.join("public/images/hero")
    filenames = if File.directory?(hero_dir)
      pattern = File.join(hero_dir, "hero-*.{png,jpg,jpeg}")
      Dir.glob(pattern).map { |p| File.basename(p) }.sort
    else
      []
    end
    render json: { filenames: filenames }
  end

  private

  def extract_item_from_path
    # Match /books/:id or /toys/:id patterns (matches sitemap URLs)
    match = request.path.match(%r{^/(?:books|toys)/(\d+)$})
    return nil unless match

    item_id = match[1].to_i
    Item.available.find_by(id: item_id)
  end
end
