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
    assert_equal ItemRequest::CANCELLED_STATUS, ItemRequest.find(item_requests(:one).id).status
  end

  test "returns 422 when cancelling a declined request" do
    item_requests(:one).update!(status: ItemRequest::DECLINED_STATUS)
    sign_in_as(users(:two))
    delete api_item_request_url(item_requests(:one))
    assert_response :unprocessable_entity
    assert_includes response.parsed_body["errors"], "Cannot cancel a declined request"
    assert_equal ItemRequest::DECLINED_STATUS, item_requests(:one).reload.status
  end

  test "returns 422 when uncancelling a request on a donated item" do
    item_requests(:one).update!(status: ItemRequest::CANCELLED_STATUS)
    items(:one).update!(status: ShareableItemStatus::DONATED)
    sign_in_as(users(:two))
    patch api_item_request_url(item_requests(:one)), params: { action_type: "uncancel" }
    assert_response :unprocessable_entity
    assert_includes response.parsed_body["errors"], "This item has already been donated"
  end

  test "returns 422 when accepting a completed request" do
    item_requests(:one).update!(status: ItemRequest::COMPLETED_STATUS)
    items(:one).update!(status: ShareableItemStatus::DONATED)
    sign_in_as(users(:one))
    patch api_item_request_url(item_requests(:one)), params: { action_type: "accept" }
    assert_response :unprocessable_entity
    assert_includes response.parsed_body["errors"], "Cannot accept a completed request"
    assert_equal ShareableItemStatus::DONATED, items(:one).reload.status
  end

  test "should get messages" do
    sign_in_as(users(:one))
    get messages_api_item_request_url(item_requests(:one))
    assert_response :success
  end
end
