require "test_helper"

class Api::ItemRequestsControllerTest < ActionDispatch::IntegrationTest
  test "should get index and expose status by name" do
    sign_in_as(users(:one))
    get api_item_requests_url, params: { type: "received" }
    assert_response :success
    json = response.parsed_body
    assert json.is_a?(Array)
    assert json.any?
    first = json.first
    record = ItemRequest.find(first["id"])
    assert record.pending?
    assert record.item.available?
    assert_equal record.status, first["status"]
    assert_equal "Pending", first["status_display"]
    assert_equal record.item.status, first.dig("book", "status") || first.dig("toy", "status")
  end

  test "should get show and expose status by name" do
    req = item_requests(:one)
    assert req.pending?
    assert req.item.available?

    sign_in_as(users(:one))
    get api_item_request_url(req)
    assert_response :success
    json = response.parsed_body
    assert_equal req.status, json["status"]
    assert_equal "Pending", json["status_display"]
    assert_equal req.item.status, json.dig("book", "status")
    assert_equal "Available", json.dig("book", "status_display")
  end

  test "should create item request and expose pending status by name" do
    sign_in_as(users(:one))
    ItemRequest.where(item: items(:two), requester: users(:one)).destroy_all

    group = community_groups(:one)
    GroupItemAvailability.find_or_create_by!(item: items(:two), community_group: group)

    post api_item_requests_url, params: {
      item_id: items(:two).id,
      message: "I would like to borrow this book please"
    }
    assert_response :created
    json = response.parsed_body
    created = ItemRequest.find(json["id"])
    assert created.pending?
    assert_equal created.status, json["status"]
    assert_equal "Pending", json["status_display"]
  end

  test "should update item request and expose updated status by name" do
    req = item_requests(:one)
    sign_in_as(users(:one))
    patch api_item_request_url(req), params: { action_type: "accept" }
    assert_response :success
    req.reload
    assert req.accepted?
    assert req.item.requested?
    json = response.parsed_body
    assert_equal req.status, json["status"]
    assert_equal "Accepted", json["status_display"]
    assert_equal req.item.status, json.dig("book", "status")
    assert_equal "Requested", json.dig("book", "status_display")
  end

  test "should destroy item request and expose cancelled status by name" do
    req = item_requests(:one)
    sign_in_as(users(:two))
    delete api_item_request_url(req)
    assert_response :success
    req.reload
    assert req.cancelled?
    json = response.parsed_body
    assert_equal req.status, json["status"]
    assert_equal "Cancelled", json["status_display"]
    assert_equal req.id, json["id"]
    assert ItemRequest.exists?(req.id)
  end

  test "should get messages" do
    sign_in_as(users(:one))
    get messages_api_item_request_url(item_requests(:one))
    assert_response :success
  end

end
