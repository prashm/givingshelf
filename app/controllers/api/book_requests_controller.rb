class Api::BookRequestsController < ApplicationController
  before_action :require_authentication
  before_action :set_book_request, only: [:update, :destroy]

  def create
    @book = Book.find(params[:book_id])
    
    unless @book.can_be_requested_by?(Current.user)
      render json: { error: "Cannot request this book" }, status: :unprocessable_entity
      return
    end

    @book_request = Current.user.book_requests.build(book: @book, message: params[:message])
    
    if @book_request.save
      render json: request_json(@book_request), status: :created
    else
      render json: { errors: @book_request.errors.full_messages }, status: :unprocessable_entity
    end
  end

  def update
    # Only the book owner can update the request status
    if @book_request.book.user != Current.user
      render json: { error: "Not authorized" }, status: :forbidden
      return
    end

    case params[:action_type]
    when 'accept'
      @book_request.accept!
      render json: request_json(@book_request)
    when 'decline'
      @book_request.decline!
      render json: request_json(@book_request)
    when 'complete'
      @book_request.complete!
      render json: request_json(@book_request)
    else
      render json: { error: "Invalid action" }, status: :unprocessable_entity
    end
  end

  def destroy
    # Only the requester can cancel their own request
    if @book_request.requester != Current.user
      render json: { error: "Not authorized" }, status: :forbidden
      return
    end

    @book_request.destroy
    render json: { message: "Request cancelled successfully" }
  end

  private

  def set_book_request
    @book_request = BookRequest.find(params[:id])
  end

  def request_json(request)
    {
      id: request.id,
      status: request.status,
      message: request.message,
      created_at: request.created_at,
      updated_at: request.updated_at,
      book: {
        id: request.book.id,
        title: request.book.title,
        author: request.book.author,
        condition: request.book.condition,
        cover_image_url: request.book.cover_image.attached? ? rails_blob_url(request.book.cover_image) : nil,
        owner: {
          id: request.book.user.id,
          name: request.book.user.display_name,
          location: request.book.user.location,
          verified: request.book.user.verified?
        }
      },
      requester: {
        id: request.requester.id,
        name: request.requester.display_name,
        location: request.requester.location,
        verified: request.requester.verified?
      }
    }
  end
end
