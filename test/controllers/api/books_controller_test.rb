require "test_helper"

class Api::BooksControllerTest < ActionDispatch::IntegrationTest
  test "should get index" do
    get api_books_url
    assert_response :success
  end

  test "should get show" do
    get api_book_url(books(:one))
    assert_response :success
  end

  test "should create book" do
    sign_in_as(users(:one))
    post api_books_url, params: {
      book: {
        title: "Test Book",
        author: "Test Author",
        condition: "good",
        summary: "This is a test book summary that is long enough.",
        genre: "Fiction",
        published_year: 2020
      }
    }
    assert_response :created
  end

  test "should update book" do
    sign_in_as(users(:one))
    patch api_book_url(books(:one)), params: { book: { title: "Updated Title" } }
    assert_response :success
  end

  test "should destroy book" do
    sign_in_as(users(:one))
    delete api_book_url(books(:one))
    assert_response :success
  end

  test "should search books" do
    get search_api_books_url, params: { query: "Test", zip_code: "12345" }
    assert_response :success
  end
end
