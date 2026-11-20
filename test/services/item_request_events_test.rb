require "test_helper"
require "minitest/spec"

# GS-9 Part A: every status change records one transition event in the request's thread.
class ItemRequestEventsTest < ActiveSupport::TestCase
  include ActionCable::TestHelper
  extend Minitest::Spec::DSL

  def setup
    @owner = users(:one)
    @requester = users(:two)
    @group = community_groups(:one)
    [ @owner, @requester ].each { |user| CommunityGroupMembership.find_or_create_by!(user: user, community_group: @group) }
    @book = items(:one)
    ItemRequest.where(item: @book).destroy_all
    GroupItemAvailability.where(item: @book).delete_all
    GroupItemAvailability.create!(item: @book, community_group: @group)
    @book.update!(status: ShareableItemStatus::AVAILABLE)
  end

  def create_user(name)
    user = User.create!(email_address: "#{name}_#{SecureRandom.hex(4)}@example.com", verified: true,
      password_digest: BCrypt::Password.create("password123!"))
    user.update_columns(first_name: name.capitalize, last_name: "Tester", zip_code: "12345")
    CommunityGroupMembership.create!(user: user, community_group: @group)
    user
  end

  def request_for(requester = @requester, message = "I would love to read this book, please.")
    service = ItemRequestService.new
    request = service.create_request(requester, @book.id, message)
    assert request, service.errors.to_sentence
    request
  end

  def events(request)
    request.messages.transitions.order(:created_at, :id)
  end

  def event_summary(request)
    events(request).map { |event| [ event.request_transition_status, event.user_id, event.content ] }
  end

  describe "creating a request" do
    it "writes the initial PENDING event, by the requester, with the request message" do
      request = request_for

      assert_equal [ [ ItemRequest::PENDING_STATUS, @requester.id, "I would love to read this book, please." ] ], event_summary(request)
      assert_equal "I would love to read this book, please.", request.initial_message.content
      assert_equal "requested", ItemRequestService.message_json(events(request).first)[:event]
    end

    it "checks the message length and creates nothing when it's wrong" do
      service = ItemRequestService.new
      assert_no_difference [ "ItemRequest.count", "Message.count" ] do
        assert_nil service.create_request(@requester, @book.id, "too short")
      end
      assert_equal [ "Message is too short (minimum is 10 characters)" ], service.errors

      service = ItemRequestService.new
      assert_nil service.create_request(@requester, @book.id, "x" * 501)
      assert_equal [ "Message is too long (maximum is 500 characters)" ], service.errors
    end

    it "writes the initial event for a new wish too" do
      service = BookService.new
      wish = service.create_wishlist_item(@requester, {
        title: "Evented Wish", author: "Author", published_year: 2020, community_group_id: @group.id,
        summary: "A summary that is more than long enough to validate successfully.", message: "Please, anyone?"
      })
      assert wish, service.errors.to_sentence
      assert_equal [ [ ItemRequest::PENDING_STATUS, @requester.id, "Please, anyone?" ] ], event_summary(service.item_request)
    end
  end

  describe "status changes" do
    it "writes one IN_REVIEW event when the owner first opens the request, and none after" do
      request = request_for
      service = ItemRequestService.new(request)

      assert service.update_request(@owner, "mark_as_viewed")
      assert service.update_request(@owner, "mark_as_viewed")

      assert_equal [ ItemRequest::PENDING_STATUS, ItemRequest::IN_REVIEW_STATUS ], events(request).pluck(:request_transition_status)
      viewed = events(request).last
      assert_equal @owner.id, viewed.user_id
      assert_nil viewed.content
      assert_equal "viewed", ItemRequestService.message_json(viewed)[:event]
    end

    it "records accept, decline, cancel and reopen with their author and note" do
      first = request_for
      second = request_for(create_user("second"))

      assert ItemRequestService.new(first).update_request(@owner, "accept", note: "  Pick up Saturday?  ")
      assert ItemRequestService.new(first.reload).cancel_request(@requester, note: "Plans changed")
      assert ItemRequestService.new(first.reload).update_request(@requester, "uncancel")
      assert ItemRequestService.new(second.reload).update_request(@owner, "decline", note: "Promised to a neighbour")

      assert_equal [
        [ ItemRequest::PENDING_STATUS, @requester.id, "I would love to read this book, please." ],
        [ ItemRequest::ACCEPTED_STATUS, @owner.id, "Pick up Saturday?" ],
        [ ItemRequest::CANCELLED_STATUS, @requester.id, "Plans changed" ],
        [ ItemRequest::PENDING_STATUS, @requester.id, nil ]
      ], event_summary(first)
      assert_equal [ ItemRequest::DECLINED_STATUS, @owner.id, "Promised to a neighbour" ], event_summary(second).last
      kinds = events(first).map { |event| ItemRequestService.message_json(event)[:event] }
      assert_equal %w[requested accepted cancelled reopened], kinds
      assert_equal "declined", ItemRequestService.message_json(events(second).last)[:event]
    end

    it "records completion, and declines the other open requests with the close-out note" do
      winner = request_for
      other = request_for(create_user("other"))
      ItemRequestService.new(winner).accept!
      ItemRequestService.new(winner.reload).update_request(@owner, "complete", note: "Enjoy!")

      assert_equal [ ItemRequest::COMPLETED_STATUS, @owner.id, "Enjoy!" ], event_summary(winner).last
      closed = events(other).last
      assert_equal [ ItemRequest::DECLINED_STATUS, @owner.id, ItemRequestService::CLOSE_OUT_DECLINED_NOTE ],
        [ closed.request_transition_status, closed.user_id, closed.content ]
      assert_equal "closed_out", ItemRequestService.message_json(closed)[:event]
    end

    it "writes no event when the change fails, or rolls back" do
      request = request_for
      ItemRequestService.new(request).accept!
      service = ItemRequestService.new(request.reload)

      assert_no_difference -> { Message.count } do
        assert_not service.update_request(@owner, "accept"), "accepting twice is refused"
        request.item.stub(:update!, ->(*) { raise ActiveRecord::RecordNotSaved, "item save failed" }) do
          assert_raises(ActiveRecord::RecordNotSaved) { ItemRequestService.new(request).complete! }
        end
      end
      assert_equal ItemRequest::ACCEPTED_STATUS, request.reload.status
    end

    it "refuses a note over 1000 characters and leaves the request as it was" do
      request = request_for
      service = ItemRequestService.new(request)

      assert_not service.update_request(@owner, "decline", note: "x" * 1001)
      assert_equal ItemRequest::PENDING_STATUS, request.reload.status
      assert_equal 1, events(request).count
    end

    it "pushes each event to the thread only once it commits" do
      request = request_for
      assert_broadcasts("item_request_#{request.id}", 1) do
        ItemRequestService.new(request).update_request(@owner, "accept")
      end
      # complete! writes its event, then fails updating the item: the event rolls back unsent.
      request.reload
      assert_no_broadcasts("item_request_#{request.id}") do
        request.item.stub(:update!, ->(*) { raise ActiveRecord::RecordNotSaved, "nope" }) do
          assert_not ItemRequestService.new(request).update_request(@owner, "complete")
        end
      end
      assert_equal ItemRequest::ACCEPTED_STATUS, request.reload.status
    end
  end

  describe "wishes" do
    def wish_with_waiters(*requesters)
      wish = Book.create!(
        user_id: nil, title: "Thread Wish", author: "Author", genre: "Fiction", published_year: 2020,
        summary: "Summary text long enough for validations on the book model here.",
        status: ShareableItemStatus::WISHLIST
      )
      GroupItemAvailability.create!(item: wish, community_group: @group)
      requests = requesters.map { |user| ItemRequestService.new.start_request!(user, wish, "Please may I have this one?") }
      [ wish, requests ]
    end

    it "records the donor fulfilling a wish as donor_found, with no stored note" do
      wish, (request, _) = wish_with_waiters(@requester)
      assert ItemService.new(wish).fulfill_wishlist_item(@owner, { condition: "good" })

      matched = events(request.reload).last
      assert_equal [ ItemRequest::IN_REVIEW_STATUS, @owner.id, nil ], [ matched.request_transition_status, matched.user_id, matched.content ]
      json = ItemRequestService.message_json(matched)
      assert_equal "donor_found", json[:event]
      assert_equal "donor", json[:user_role]
    end

    it "keeps a moved wisher's thread, with the previous donor's messages still named as the donor" do
      second_user = create_user("second")
      wish, (first, second) = wish_with_waiters(@requester, second_user)
      assert ItemService.new(wish).fulfill_wishlist_item(@owner, { condition: "good" })
      second.reload.messages.create!(user: @owner, content: "Sorry, it may go to someone else")
      ItemRequestService.new(first.reload).accept!
      ItemRequestService.new(first.reload).complete!

      second.reload
      assert_not_equal wish.id, second.item_id
      thread = second.messages.order(:created_at, :id).to_a
      assert_equal [ "requested", "donor_found", nil, "moved" ],
        thread.map { |message| ItemRequestService.message_json(message)[:event] }
      assert_equal ItemRequestService::CLOSE_OUT_MOVED_NOTE, thread.last.content
      assert_equal [ "requester", "donor", "donor", "donor" ],
        thread.map { |message| ItemRequestService.message_json(message)[:user_role] }
      assert_equal "Please may I have this one?", second.initial_message.content
      assert_not second.message_thread_writable?, "no donor on the new wish yet"
    end
  end

  describe "#initial_message" do
    it "is the first PENDING event, looked up once, and again after a reload" do
      request = request_for
      first_event = events(request).first
      assert_equal first_event, request.initial_message
      ActiveRecord::Base.uncached { assert_no_queries { request.initial_message } }

      ItemRequestService.new(request).cancel!
      ItemRequestService.new(request.reload).uncancel!
      assert_equal first_event, request.reload.initial_message, "a reopen is not the initial message"
    end

    it "is looked up again after a reload, so a missing event found later is picked up" do
      request = ItemRequest.create!(item: @book, requester: @requester)
      assert_nil request.initial_message
      request.messages.create!(user: @requester, request_transition_status: ItemRequest::PENDING_STATUS, content: "Backfilled later")

      assert_equal "Backfilled later", request.reload.initial_message.content
    end

    it "names each event in a thread with one lookup of the initial message" do
      request = request_for
      ItemRequestService.new(request).cancel!
      ItemRequestService.new(request.reload).uncancel!
      thread = ItemRequest.find(request.id).messages.includes(:user).order(:created_at, :id).to_a

      kinds = nil
      message_queries = 0
      count = ->(*, payload) { message_queries += 1 if payload[:sql].include?('FROM "messages"') }
      kinds = ActiveRecord::Base.uncached do
        ActiveSupport::Notifications.subscribed(count, "sql.active_record") do
          thread.map { |message| ItemRequestService.message_json(message)[:event] }
        end
      end
      assert_equal 1, message_queries, "the initial message is looked up once for the whole thread"
      assert_equal %w[requested cancelled reopened], kinds
    end
  end

  describe "#message_thread_writable?" do
    it "is open while the request is live with an owner, and closed otherwise" do
      request = request_for
      assert request.message_thread_writable?

      ItemRequestService.new(request).cancel!
      assert_not request.reload.message_thread_writable?
      ItemRequestService.new(request).uncancel!
      assert request.reload.message_thread_writable?
      ItemRequestService.new(request).decline!
      assert_not request.reload.message_thread_writable?
    end
  end
end
