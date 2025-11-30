class Api::BooksController < ApplicationController
  before_action :require_authentication, except: [ :index, :show, :search, :track_view ]
  before_action :set_book, only: [ :show, :update, :destroy, :track_view ]

  def index
    @books = Book.available.includes(:user).recent
    render json: @books.map { |book| book_json(book) }
  end

  def my_books
    @books = Current.user.books.includes(:book_requests).recent
    render json: @books.map { |book| my_book_json(book) }
  end

  def show
    render json: book_json(@book)
  end

  def create
    @book = Current.user.books.build(book_params.except(:api_cover_image))
    
    # Handle API cover image URL if provided (before save so it can be attached)
    handle_api_cover_image(@book) if params[:book][:api_cover_image].present? && params[:book][:api_cover_image].is_a?(String)

    if @book.save
      render json: book_json(@book), status: :created
    else
      render json: { errors: @book.errors.full_messages }, status: :unprocessable_entity
    end
  end

  def update
    if @book.user != Current.user
      render json: { error: "Not authorized" }, status: :forbidden
      return
    end

    # Handle API cover image URL if provided (before update so it can be attached)
    handle_api_cover_image(@book) if params[:book][:api_cover_image].present? && params[:book][:api_cover_image].is_a?(String)

    # Handle user_images separately to merge with existing instead of replacing
    update_params = book_params.except(:api_cover_image, :user_images, :remove_user_image_indices)
    new_user_images = params[:book][:user_images]
    
    # Handle removed existing images
    if params[:book][:remove_user_image_indices].present?
      indices_to_remove = params[:book][:remove_user_image_indices].map(&:to_i)
      existing_images = @book.user_images.to_a
      # Remove in reverse order to maintain correct indices
      indices_to_remove.sort.reverse.each do |index|
        if existing_images[index]
          existing_images[index].purge
        end
      end
    end

    # Add new images if any were uploaded (merge with existing)
    if new_user_images.present?
      Array(new_user_images).each do |image|
        @book.user_images.attach(image) if image.present?
      end
    end

    # Update other book attributes (excluding user_images handling which is done above)
    if @book.update(update_params)
      render json: book_json(@book)
    else
      render json: { errors: @book.errors.full_messages }, status: :unprocessable_entity
    end
  end

  def destroy
    if @book.user != Current.user
      render json: { error: "Not authorized" }, status: :forbidden
      return
    end

    @book.destroy
    render json: { message: "Book deleted successfully" }
  end

  def search
    query = params[:query]
    zip_code = params[:zip_code]

    @books = Book.search(query, zip_code)
    render json: @books.map { |book| book_json(book) }
  end

  def track_view
    # Only increment view count if the viewer is not the book owner
    if Current.user.nil? || Current.user.id != @book.user_id
      @book.increment!(:view_count)
    end
    render json: { view_count: @book.view_count }
  end

  private

  def set_book
    @book = Book.find(params[:id])
  end

  def book_params
    params.require(:book).permit(:title, :author, :condition, :summary, :isbn, :genre, :published_year, :cover_image, :api_cover_image, user_images: [])
  end

  def handle_api_cover_image(book)
    api_url = params[:book][:api_cover_image]
    return unless api_url.present?
    
    # Only process if it's a string URL, not a File object
    return unless api_url.is_a?(String) && api_url.match?(/\Ahttps?:\/\//)

    begin
      # Ensure URL uses HTTPS
      secure_url = api_url.gsub(/^http:/, 'https:')
      
      # Fetch the image from the URL
      require 'open-uri'
      downloaded_image = URI.open(secure_url, read_timeout: 10)
      
      # Determine content type from response or default to jpeg
      content_type = downloaded_image.content_type || 'image/jpeg'
      extension = content_type.split('/').last || 'jpg'
      filename = "cover_image_#{SecureRandom.hex(8)}.#{extension}"
      
      # Attach the downloaded image to the book
      book.cover_image.attach(
        io: downloaded_image,
        filename: filename,
        content_type: content_type
      )
    rescue => e
      Rails.logger.error("Failed to download cover image from #{api_url}: #{e.message}")
      # Don't fail the request if image download fails, just log the error
    end
  end

  def book_json(book)
    {
      id: book.id,
      title: book.title,
      author: book.author,
      condition: book.condition,
      summary: book.summary,
      isbn: book.isbn,
      genre: book.genre,
      published_year: book.published_year,
      status: book.status,
      cover_image_url: book.cover_image.attached? ? book.cover_image.attachment.url : nil,
      user_images_urls: book.user_images.attached? ? book.user_images.map { |img| img.url } : [],
      view_count: book.view_count || 0,
      owner: {
        id: book.user.id,
        name: book.user.display_name,
        location: book.user.location,
        verified: book.user.verified?
      },
      created_at: book.created_at,
      updated_at: book.updated_at,
      can_request: Current.user ? book.can_be_requested_by?(Current.user) : false
    }
  end

  def my_book_json(book)
    {
      id: book.id,
      title: book.title,
      author: book.author,
      condition: book.condition,
      status: book.status,
      cover_image_url: book.cover_image.attached? ? book.cover_image.attachment.url : nil,
      created_at: book.created_at,
      request_count: book.book_requests.count
    }
  end
end
