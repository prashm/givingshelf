require "test_helper"
require Rails.root.join("db/migrate/20261120120100_backfill_initial_request_events")

class BackfillInitialRequestEventsTest < ActiveSupport::TestCase
  def backfill!
    ActiveRecord::Base.connection.execute(BackfillInitialRequestEvents.backfill_sql)
  end

  def set_message(request, message)
    ActiveRecord::Base.connection.exec_update("UPDATE item_requests SET message = $1 WHERE id = $2", "set message", [ message, request.id ])
  end

  test "gives each request one initial PENDING event with its message, author and created_at" do
    request = item_requests(:one)
    request.update_columns(created_at: 3.days.ago.change(usec: 0), status: ItemRequest::DECLINED_STATUS)
    set_message(request, "  I would love to read this book!  ")
    blank = item_requests(:two)
    set_message(blank, "")
    request.messages.create!(user: users(:one), content: "A chat message isn't an initial event")

    backfill!
    backfill!

    events = request.messages.transitions.to_a
    assert_equal 1, events.size, "running it twice adds nothing"
    event = events.first
    assert_equal [ ItemRequest::PENDING_STATUS, request.requester_id, "I would love to read this book!", request.created_at ],
      [ event.request_transition_status, event.user_id, event.content, event.created_at ]
    assert_equal "I would love to read this book!", request.initial_message.content
    assert_nil blank.messages.transitions.sole.content
    assert_equal ItemRequest.count, Message.transitions.where(request_transition_status: ItemRequest::PENDING_STATUS).count
  end
end
