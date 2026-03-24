class HomeController < ApplicationController
  allow_unauthenticated_access only: [ :index, :growth_stats ]

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

  def growth_stats
    stats = [
      { id: "local_givers", value: "100+", label: "Local Givers" },
      { id: "items_shared", value: "200+", label: "Books & Toys Shared" },
      { id: "groups_created", value: "15+", label: "Local Groups Created" }
    ]
    # TODO: Implement actual growth stats
    render json: { stats: stats }
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
