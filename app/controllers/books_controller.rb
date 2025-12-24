class BooksController < ApplicationController
  allow_unauthenticated_access only: [ :index ]

  def index
    # Detect if this is a book detail page (/books/:id)
    # Extract book ID from the path for SEO meta tags
    @book = extract_book_from_path if request.format.html?

    respond_to do |format|
      format.html do
        # For HTML requests, render the React app
        render "index"
      end
      format.json do
        # For JSON requests, return a simple response or redirect to API
        render json: { message: "Please use /api/books for JSON requests" }, status: :not_acceptable
      end
    end
  end

  private

  def extract_book_from_path
    # Match /books/:id pattern
    match = request.path.match(%r{^/books/(\d+)$})
    return nil unless match

    book_id = match[1].to_i
    Book.available.find_by(id: book_id)
  end
end
