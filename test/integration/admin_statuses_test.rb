# frozen_string_literal: true

require "test_helper"

class AdminStatusesTest < ActionDispatch::IntegrationTest
  setup do
    @admin = User.create!(
      email_address: "admin_#{SecureRandom.hex(4)}@example.com",
      password_digest: BCrypt::Password.create("password123!"),
      admin: true,
      verified: true
    )
    sign_in_as(@admin)
  end

  test "ActiveAdmin books index, status filter, show, edit, and update work with enum statuses" do
    available_book = items(:one)
    wishlist_book = Book.create!(
      type: Book.name,
      user_id: nil,
      title: "Admin Wishlist Book",
      author: "Wish Author",
      summary: "Summary long enough to pass validation for admin test.",
      published_year: 2021,
      genre: "Fiction",
      status: :wishlist
    )

    get "/admin/books"
    assert_response :success
    assert_includes response.body, available_book.title
    assert_includes response.body, wishlist_book.title
    assert_includes response.body, "Wishlist"

    get "/admin/books", params: { q: { status_eq: Book.statuses[:wishlist] } }
    assert_response :success
    assert_includes response.body, wishlist_book.title
    assert_not_includes response.body, available_book.title

    get "/admin/books/#{wishlist_book.id}"
    assert_response :success
    assert_includes response.body, "Wishlist"

    get "/admin/books/#{available_book.id}/edit"
    assert_response :success
    assert_match(/option[^>]*selected="selected"[^>]*value="available"/, response.body)

    patch "/admin/books/#{available_book.id}", params: { book: { status: "donated" } }
    assert_redirected_to "/admin/books/#{available_book.id}"
    assert_equal "donated", available_book.reload.status
  end

  test "ActiveAdmin toys index, status filter, edit, and update work with enum statuses" do
    toy = items(:toy_one)
    other_toy = items(:toy_two)
    other_toy.donated!

    get "/admin/toys", params: { q: { status_eq: Toy.statuses[:donated] } }
    assert_response :success
    assert_includes response.body, other_toy.title
    assert_not_includes response.body, toy.title

    get "/admin/toys/#{toy.id}/edit"
    assert_response :success
    assert_match(/option[^>]*selected="selected"[^>]*value="available"/, response.body)

    patch "/admin/toys/#{toy.id}", params: { toy: { status: "requested" } }
    assert_redirected_to "/admin/toys/#{toy.id}"
    assert_equal "requested", toy.reload.status
  end

  test "ActiveAdmin item_requests index, status filter, show, edit, and update work with enum statuses" do
    req_one = item_requests(:one)
    req_two = item_requests(:two)
    req_two.accepted!

    get "/admin/item_requests", params: { q: { status_eq: ItemRequest.statuses[:accepted] } }
    assert_response :success
    assert_includes response.body, "/admin/item_requests/#{req_two.id}"
    assert_not_includes response.body, "/admin/item_requests/#{req_one.id}"

    get "/admin/item_requests/#{req_two.id}"
    assert_response :success
    assert_includes response.body, "Accepted"

    get "/admin/item_requests/#{req_two.id}/edit"
    assert_response :success
    assert_match(/option[^>]*selected="selected"[^>]*value="accepted"/, response.body)

    patch "/admin/item_requests/#{req_one.id}", params: { item_request: { status: "in_review" } }
    assert_redirected_to "/admin/item_requests/#{req_one.id}"
    assert_equal "in_review", req_one.reload.status
  end
end
