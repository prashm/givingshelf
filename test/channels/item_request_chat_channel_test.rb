require "test_helper"

class ItemRequestChatChannelTest < ActionCable::Channel::TestCase
  test "accepts a message while the request is live" do
    request = item_requests(:one)
    stub_connection current_user: users(:one)
    subscribe item_request_id: request.id

    assert_difference -> { request.messages.count }, 1 do
      perform :receive, "content" => "When can you pick it up?"
    end
  end

  test "refuses messages once the request is closed" do
    request = item_requests(:one)
    request.update_columns(status: :cancelled)
    stub_connection current_user: users(:one)
    subscribe item_request_id: request.id

    assert_no_difference -> { Message.count } do
      perform :receive, "content" => "Anyone there?"
    end
    assert_equal({ "type" => "error", "message" => "This conversation is closed" }, transmissions.last)
  end
end
