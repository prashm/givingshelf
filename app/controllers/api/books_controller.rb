class Api::BooksController < ApplicationController
  before_action :require_authentication, except: [ :index, :show, :search, :track_view, :stats ]
  before_action :resume_session, only: [ :show, :track_view ]
  before_action :set_book, only: [ :show, :update, :destroy, :track_view ]

  include ApiCursorPagination

  def index
    paginated_books_response Book.available.includes(:user).recent
  end

  def my_books
    @books = Current.user.books.includes(:item_requests).recent
    render json: {
      statuses: ShareableItemStatus.data,
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
    paginated_books_response book_service.search_books(
      query_string: params[:query],
      zip_code: params[:zip_code],
      radius: params[:radius],
      community_group_id: params[:community_group_id],
      sub_group_id: params[:sub_group_id]
    )
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

    request = @book.item_requests.find_by(requester: Current.user, status: [ ItemRequest::PENDING_STATUS, ItemRequest::ACCEPTED_STATUS ])

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
    if params[:community_group_id].present?
      if params[:community_group_id].to_i <= 0 || !CommunityGroup.exists?(params[:community_group_id].to_i)
        render json: { error: "Group not found" }, status: :not_found
        return
      end
      stats = book_service.community_group_stats(community_group_id: params[:community_group_id], sub_group_id: params[:sub_group_id])
    else
      stats = book_service.community_stats(zip_code: params[:zip_code], radius: params[:radius])
    end
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
    :cover_image, :api_cover_image, :personal_note, :pickup_method, :pickup_address,
    community_group_ids: [], user_images: [], remove_user_image_indices: [])
  end

  def my_book_json(book)
    {
      id: book.id,
      title: book.title,
      author: book.author,
      condition: book.condition,
      status: book.status,
      status_display: ShareableItemStatus.display_status(book.status),
      cover_image_url: book.cover_image.attached? ? book.cover_image.attachment.url : nil,
      created_at: book.created_at
    }
  end

  def paginated_books_response(books)
    @errors = []
    # Validate and set pagination options from params
    validate_and_setup_page_params(params[:page])

    if @errors.blank?
      paginated_books = paginate(books.select("items.*, items.id as item_id"), "items.id", "item_id")
      # Build API response with pagination metadata
      response = {
        status: "Success",
        data: paginated_books.map { |book| my_book_json(book) }
      }.merge(page_links_and_meta_data(request.base_url + request.path, request.query_parameters))

      render json: response, status: :ok
    else
      render json: error_response, status: :unprocessable_entity
    end
  end

  def error_response
    {
      status: "Error",
      errors: @errors.map { |error| error.is_a?(Hash) ? error : { title: error } }
    }
  end
end
