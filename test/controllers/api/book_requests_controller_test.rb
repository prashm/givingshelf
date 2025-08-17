require "test_helper"

class Api::BookRequestsControllerTest < ActionDispatch::IntegrationTest
  test "should get create" do
    get api_book_requests_create_url
    assert_response :success
  end

  test "should get update" do
    get api_book_requests_update_url
    assert_response :success
  end

  test "should get destroy" do
    get api_book_requests_destroy_url
    assert_response :success
  end
end
