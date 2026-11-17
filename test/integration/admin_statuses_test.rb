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
    wishlist_book = Book.wishlist.create!(
      type: Book.name,
      user_id: nil,
      title: "Admin Wishlist Book",
      author: "Wish Author",
      summary: "Summary long enough to pass validation for admin test.",
      published_year: 2021,
      genre: "Fiction"
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
    assert_match(/option[^>]*selected="selected"[^>]*value="#{available_book.status}"/, response.body)

    patch "/admin/books/#{available_book.id}", params: { book: { status: Book.donated.new.status } }
    assert_redirected_to "/admin/books/#{available_book.id}"
    assert available_book.reload.donated?
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
    assert_match(/option[^>]*selected="selected"[^>]*value="#{toy.status}"/, response.body)

    patch "/admin/toys/#{toy.id}", params: { toy: { status: Toy.requested.new.status } }
    assert_redirected_to "/admin/toys/#{toy.id}"
    assert toy.reload.requested?
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
    assert_match(/option[^>]*selected="selected"[^>]*value="#{req_two.status}"/, response.body)

    patch "/admin/item_requests/#{req_one.id}", params: { item_request: { status: ItemRequest.in_review.new.status } }
    assert_redirected_to "/admin/item_requests/#{req_one.id}"
    assert req_one.reload.in_review?
  end

  test "ActiveAdmin group_membership_requests index, status filter, show, edit, and update work with enum statuses" do
    join_user = User.create!(
      email_address: "admin_gmr_user_#{SecureRandom.hex(4)}@example.com",
      password_digest: BCrypt::Password.create("password123!"),
      verified: true
    )
    join_req = GroupMembershipRequest.requested.create!(
      community_group: community_groups(:one),
      requester: join_user,
      requester_type: "User",
      message: "Would love to join"
    )
    invite_req = GroupMembershipRequest.invited.create!(
      community_group: community_groups(:two),
      requester: users(:one),
      requester_type: "Admin",
      email_address: "admin_gmr_invite_#{SecureRandom.hex(4)}@example.com",
      message: "Please join"
    )

    get "/admin/group_membership_requests"
    assert_response :success
    assert_includes response.body, "/admin/group_membership_requests/#{join_req.id}"
    assert_includes response.body, "/admin/group_membership_requests/#{invite_req.id}"
    assert_includes response.body, "Requested"
    assert_includes response.body, "Invited"

    get "/admin/group_membership_requests", params: { q: { status_eq: GroupMembershipRequest.statuses[:invited] } }
    assert_response :success
    assert_includes response.body, "/admin/group_membership_requests/#{invite_req.id}"
    assert_not_includes response.body, "/admin/group_membership_requests/#{join_req.id}"

    get "/admin/group_membership_requests/#{invite_req.id}"
    assert_response :success
    assert_includes response.body, "Invited"

    get "/admin/group_membership_requests/#{invite_req.id}/edit"
    assert_response :success
    assert_match(/option[^>]*selected="selected"[^>]*value="#{invite_req.status}"/, response.body)

    patch "/admin/group_membership_requests/#{join_req.id}", params: {
      group_membership_request: { status: GroupMembershipRequest.accepted.new.status }
    }
    assert_redirected_to "/admin/group_membership_requests/#{join_req.id}"
    assert join_req.reload.accepted?
  end
end
