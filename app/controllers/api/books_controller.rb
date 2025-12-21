class Api::BooksController < ApplicationController
  before_action :require_authentication, except: [ :index, :show, :search, :track_view, :stats ]
  before_action :set_book, only: [ :show, :update, :destroy, :track_view ]

  def index
    @books = Book.available.includes(:user).recent
    render json: @books.map { |book| book_service.book_json(book, Current.user) }
  end

  def my_books
    @books = Current.user.books.includes(:book_requests).recent
    render json: {
      statuses: BookStatus.data,
      books: @books.map { |book| my_book_json(book) }
    }
  end

  def show
    render json: book_service.book_json(@book, Current.user)
  end

  def create
    book = book_service.create_book(Current.user, book_params)
    if book
      render json: book_service.book_json(book, Current.user), status: :created
    else
      render json: { errors: book_service.errors }, status: :unprocessable_entity
    end
  end

  def update
    if book_service.update_book(Current.user, book_params)
      render json: book_service.book_json(@book, Current.user), status: :ok
    else
      render json: { errors: book_service.errors }, status: :unprocessable_entity
    end
  end

  def destroy
    if book_service.remove_book(Current.user)
      render json: { message: "Book deleted successfully" }, status: :ok
    else
      render json: { errors: book_service.errors }, status: :unprocessable_entity
    end
  end

  def search
    books = book_service.search_books(query_string: params[:query], zip_code: params[:zip_code])
    render json: books.map { |book| book_service.book_json(book, Current.user) }
  end

  def track_view
    render json: { view_count: book_service.track_book_view(Current.user) }
  end

  def user_request
    @book = Book.find(params[:id])

    unless Current.user
      render json: { has_requested: false }
      return
    end

    request = @book.book_requests.find_by(requester: Current.user, status: [ BookRequest::PENDING_STATUS, BookRequest::ACCEPTED_STATUS ])

    if request
      render json: {
        has_requested: true,
        request: {
          id: request.id,
          status: request.status,
          created_at: request.created_at,
          message: request.message
        }
      }
    else
      render json: { has_requested: false }
    end
  end

  def stats
    stats = BookService.community_stats(zip_code: params[:zip_code])
    render json: stats
  end

  private

  def book_service
    @book_service ||= BookService.new(@book)
  end

  def set_book
    @book = Book.find(params[:id])
  end

  def book_params
    params.require(:book).permit(:title, :author, :condition, :summary, :isbn, :genre, :published_year,
    :cover_image, :api_cover_image, :personal_note, :pickup_method, :pickup_address, user_images: [], remove_user_image_indices: [])
  end

  def my_book_json(book)
    {
      id: book.id,
      title: book.title,
      author: book.author,
      condition: book.condition,
      status: book.status,
      status_display: BookStatus.display_status(book.status),
      cover_image_url: book.cover_image.attached? ? book.cover_image.attachment.url : nil,
      created_at: book.created_at,
      request_count: book.book_requests.count
    }
  end
end
