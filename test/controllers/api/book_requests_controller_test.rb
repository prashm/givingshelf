require "test_helper"

class Api::BookRequestsControllerTest < ActionDispatch::IntegrationTest
  test "should get index" do
    sign_in_as(users(:one))
    get api_book_requests_url
    assert_response :success
  end

  test "should get show" do
    sign_in_as(users(:one))
    get api_book_request_url(item_requests(:one))
    assert_response :success
  end

  test "should create book request" do
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
    
    post api_book_requests_url, params: {
      book_id: items(:two).id,
      message: "I would like to borrow this book please"
    }
    assert_response :created
  end

  test "should update book request" do
    sign_in_as(users(:one))
    patch api_book_request_url(item_requests(:one)), params: { action_type: "accept" }
    assert_response :success
  end

  test "should destroy book request" do
    # item_requests(:one) has requester: two, so sign in as users(:two) to cancel their own request
    sign_in_as(users(:two))
    delete api_book_request_url(item_requests(:one))
    assert_response :success
  end

  test "should get messages" do
    sign_in_as(users(:one))
    get messages_api_book_request_url(item_requests(:one))
    assert_response :success
  end
end
