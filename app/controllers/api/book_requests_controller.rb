class Api::BookRequestsController < ApplicationController
  before_action :require_authentication
  before_action :set_book_request, only: [:show, :update, :destroy]

  def index
    book_requests = book_request_service.requests_for_user(Current.user, params[:type])
    render json: book_requests.map { |req| book_request_service.request_json(req) }
  end
  
  def show
    unless @book_request.requester == Current.user || @book_request.book.owner?(Current.user)
      render json: { error: "Not authorized" }, status: :forbidden
    else
      render json: book_request_service.request_json(@book_request)
    end
  end

  def create
    book_request = book_request_service.create_request(Current.user, params[:book_id], params[:message])
    if book_request
      render json: book_request_service.request_json(book_request), status: :created
    else
      Rails.logger.error "Book request creation failed: #{book_request_service.errors.join(', ')}"
      render json: { errors: book_request_service.errors }, status: :unprocessable_entity
    end
  end

  def update
    if book_request_service.update_request(Current.user, params[:action_type])
      render json: book_request_service.request_json(book_request_service.book_request)
    else
      render json: { errors: book_request_service.errors }, status: :unprocessable_entity
    end
  end

  def destroy
    if book_request_service.cancel_request(Current.user)
      render json: { message: "Request cancelled successfully" }
    else
      render json: { errors: book_request_service.errors }, status: :unprocessable_entity
    end
  end

  private

  def book_request_service
    @book_request_service ||= BookRequestService.new(@book_request)
  end

  def set_book_request
    @book_request = BookRequest.find(params[:id])
  end
end
