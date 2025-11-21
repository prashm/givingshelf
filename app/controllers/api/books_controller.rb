class Api::BooksController < ApplicationController
  before_action :require_authentication, except: [:index, :show, :search]
  before_action :set_book, only: [:show, :update, :destroy]

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
    @book = Current.user.books.build(book_params)
    
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

    if @book.update(book_params)
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

  private

  def set_book
    @book = Book.find(params[:id])
  end

  def book_params
    params.require(:book).permit(:title, :author, :condition, :summary, :isbn, :genre, :published_year, :cover_image)
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
