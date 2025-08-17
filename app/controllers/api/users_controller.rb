class Api::UsersController < ApplicationController
  before_action :require_authentication
  before_action :set_user, only: [:show, :update]

  def show
    if @user == Current.user || Current.user.verified?
      render json: user_json(@user)
    else
      render json: { error: "Not authorized" }, status: :forbidden
    end
  end

  def update
    if @user != Current.user
      render json: { error: "Not authorized" }, status: :forbidden
      return
    end

    if @user.update(user_params)
      render json: user_json(@user)
    else
      render json: { errors: @user.errors.full_messages }, status: :unprocessable_entity
    end
  end

  def profile
    render json: user_json(Current.user)
  end

  def my_books
    @books = Current.user.books.includes(:book_requests).recent
    render json: @books.map { |book| book_json(book) }
  end

  def my_requests
    @requests = Current.user.book_requests.includes(:book, :requester).recent
    render json: @requests.map { |request| request_json(request) }
  end

  def received_requests
    @requests = BookRequest.for_book_owner(Current.user).includes(:book, :requester).recent
    render json: @requests.map { |request| request_json(request) }
  end

  private

  def set_user
    @user = User.find(params[:id])
  end

  def user_params
    params.require(:user).permit(:first_name, :last_name, :zip_code, :phone)
  end

  def user_json(user)
    {
      id: user.id,
      email_address: user.email_address,
      first_name: user.first_name,
      last_name: user.last_name,
      full_name: user.full_name,
      display_name: user.display_name,
      zip_code: user.zip_code,
      phone: user.phone,
      verified: user.verified?,
      created_at: user.created_at,
      updated_at: user.updated_at
    }
  end

  def book_json(book)
    {
      id: book.id,
      title: book.title,
      author: book.author,
      condition: book.condition,
      status: book.status,
      cover_image_url: book.cover_image.attached? ? rails_blob_url(book.cover_image) : nil,
      created_at: book.created_at,
      request_count: book.book_requests.count
    }
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
        cover_image_url: request.book.cover_image.attached? ? rails_blob_url(request.book.cover_image) : nil
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
