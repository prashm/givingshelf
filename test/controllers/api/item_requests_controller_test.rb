require "test_helper"

class Api::ItemRequestsControllerTest < ActionDispatch::IntegrationTest
  test "should get index" do
    sign_in_as(users(:one))
    get api_item_requests_url
    assert_response :success
  end

  test "should get show" do
    sign_in_as(users(:one))
    get api_item_request_url(item_requests(:one))
    assert_response :success
  end

  test "should create item request" do
    sign_in_as(users(:one))
    # users(:one) can request items(:two) since items(:two) belongs to users(:two)
    # But first, we need to make sure there's no existing request
    # Delete any existing request from the fixtures
    ItemRequest.where(item: items(:two), requester: users(:one)).destroy_all

    # Ensure both users are in a common group (users(:one) and users(:two) are both in community_groups(:one) per fixtures)
    group = community_groups(:one)
    GroupItemAvailability.find_or_create_by!(item: items(:two), community_group: group)
    # users(:one) is already in group via community_group_memberships(:one)
    # users(:two) is already in group via community_group_memberships(:two)

    post api_item_requests_url, params: {
      item_id: items(:two).id,
      message: "I would like to borrow this book please"
    }
    assert_response :created
  end

  test "should update item request" do
    sign_in_as(users(:one))
    patch api_item_request_url(item_requests(:one)), params: { action_type: "accept" }
    assert_response :success
  end

  test "should destroy item request" do
    # item_requests(:one) has requester: two, so sign in as users(:two) to cancel their own request
    sign_in_as(users(:two))
    delete api_item_request_url(item_requests(:one))
    assert_response :success
    json = response.parsed_body
    assert_equal "Cancelled", json["status_display"]
    assert_equal item_requests(:one).id, json["id"]
    assert ItemRequest.exists?(item_requests(:one).id)
    assert_equal "cancelled", ItemRequest.find(item_requests(:one).id).status
  end

  test "returns 422 when cancelling a declined request" do
    item_requests(:one).update!(status: "declined")
    sign_in_as(users(:two))
    delete api_item_request_url(item_requests(:one))
    assert_response :unprocessable_entity
    assert_includes response.parsed_body["errors"], "Cannot cancel a declined request"
    assert_equal "declined", item_requests(:one).reload.status
  end

  test "returns 422 when uncancelling a request on a donated item" do
    item_requests(:one).update!(status: "cancelled")
    items(:one).update!(status: "donated")
    sign_in_as(users(:two))
    patch api_item_request_url(item_requests(:one)), params: { action_type: "uncancel" }
    assert_response :unprocessable_entity
    assert_includes response.parsed_body["errors"], "This item has already been donated"
  end

  test "returns 422 when accepting a completed request" do
    item_requests(:one).update!(status: "completed")
    items(:one).update!(status: "donated")
    sign_in_as(users(:one))
    patch api_item_request_url(item_requests(:one)), params: { action_type: "accept" }
    assert_response :unprocessable_entity
    assert_includes response.parsed_body["errors"], "Cannot accept a completed request"
    assert_equal "donated", items(:one).reload.status
  end

  test "should get messages" do
    sign_in_as(users(:one))
    get messages_api_item_request_url(item_requests(:one))
    assert_response :success
  end

  test "messages lists events with their kind and author role, plus whether the thread is writable" do
    request = item_requests(:one)
    request.messages.delete_all
    request.messages.create!(user: users(:two), request_transition_status: "pending", content: "Could I borrow it, please?")
    request.messages.create!(user: users(:one), content: "Sure, when suits you?")
    request.messages.create!(user: users(:one), request_transition_status: "declined", content: "Sorry, it went elsewhere")
    request.update_columns(status: "declined")

    sign_in_as(users(:one))
    get messages_api_item_request_url(request)

    assert_response :success
    body = response.parsed_body
    assert_equal false, body["message_thread_writable"]
    assert_equal [ [ "requested", "requester" ], [ nil, "owner" ], [ "declined", "owner" ] ],
      body["messages"].map { |message| message.values_at("event", "user_role") }
    assert_equal "declined", body["messages"].last["request_transition_status"]
  end

  test "update and destroy pass the note through to the event" do
    request = item_requests(:one)
    sign_in_as(users(:one))
    patch api_item_request_url(request), params: { action_type: "decline", note: "Promised to a friend" }
    assert_response :success
    assert_equal "Promised to a friend", request.messages.transitions.last.content

    other = item_requests(:two)
    sign_in_as(users(:one))
    delete api_item_request_url(other), params: { note: "Found a copy" }
    assert_response :success
    assert_equal [ "cancelled", "Found a copy" ], other.messages.transitions.last.slice(:request_transition_status, :content).values
  end

  test "a donor whose wisher was moved to a new wish can no longer open that request" do
    wish = Book.create!(user_id: nil, title: "Moved Wish", author: "Author", genre: "Fiction", published_year: 2020,
      summary: "Summary text long enough for validations on the book model here.", status: "wishlist")
    winner = ItemRequestService.new.start_request!(users(:two), wish, "Please may I have this one?")
    third = User.create!(email_address: "third_#{SecureRandom.hex(4)}@example.com", verified: true,
      password_digest: BCrypt::Password.create("password123!"))
    moved = ItemRequestService.new.start_request!(third, wish, "Me too, if there's a spare")
    assert ItemService.new(wish).fulfill_wishlist_item(users(:one), { condition: "good" })
    ItemRequestService.new(winner.reload).accept!
    ItemRequestService.new(winner.reload).complete!
    assert_not_equal wish.id, moved.reload.item_id

    sign_in_as(users(:one))
    get api_item_request_url(moved)
    assert_response :forbidden
    get messages_api_item_request_url(moved)
    assert_response :forbidden
  end

  test "a request on a deleted item still opens, and says the item was removed" do
    items(:one).update_columns(deleted_at: Time.current)
    sign_in_as(users(:two))

    get api_item_request_url(item_requests(:one))

    assert_response :success
    assert_equal true, JSON.parse(response.body)["book"]["deleted"]
  end
end
