require "test_helper"

class ItemRequestMailerTest < ActionMailer::TestCase
  test "the new request email shows the requester's message from the thread" do
    book = items(:one)
    ItemRequest.where(item: book).destroy_all
    request = ItemRequestService.new.start_request!(users(:two), book, "I would love to read this one, thanks!")

    email = ItemRequestMailer.new_request_notification(request)

    assert_equal [ book.user.email_address ], email.to
    assert_includes email.body.to_s, "I would love to read this one, thanks!"
  end
end
