class BooksController < ApplicationController
  allow_unauthenticated_access only: [ :index ]

  def index
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
end
