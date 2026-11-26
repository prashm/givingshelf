require "test_helper"
require "minitest/spec"
require "minitest/mock"

# GS-11: who each status change emails, and that nobody is emailed twice.
class RequestEventNotificationJobTest < ActiveJob::TestCase
  include ActionMailer::TestHelper
  extend Minitest::Spec::DSL

  def setup
    @owner = users(:one)
    @group = community_groups(:one)
    @book = items(:one)
    ItemRequest.where(item: @book).destroy_all
    GroupItemAvailability.where(item: @book).delete_all
    GroupItemAvailability.create!(item: @book, community_group: @group)
    @book.update!(status: "available")
    CommunityGroupMembership.find_or_create_by!(user: @owner, community_group: @group)
  end

  def member(name)
    user = User.create!(email_address: "#{name}_#{SecureRandom.hex(4)}@example.com", verified: true,
      password_digest: BCrypt::Password.create("password123!"))
    user.update_columns(first_name: name.capitalize, last_name: "Tester", zip_code: "12345")
    CommunityGroupMembership.create!(user: user, community_group: @group)
    user
  end

  # Runs every notification job queued by the block, and returns the emails they sent as
  # [to, body] pairs.
  def emails_from
    ActionMailer::Base.deliveries.clear
    perform_enqueued_jobs { yield }
    ActionMailer::Base.deliveries.map { |mail| [ mail.to.first, mail.body.to_s ] }
  end

  # Whether `sent` has an email to `user` that says `phrase`.
  def sent_to?(sent, user, phrase)
    sent.any? { |to, body| to == user.email_address && body.include?(phrase) }
  end

  def request_from(user, item = @book)
    ItemRequestService.new.start_request!(user, item, "Could I have this one, please?")
  end

  describe "status changes" do
    it "emails the owner about a new request, and the requester about accept and completion" do
      requester = member("reader")
      request = nil

      assert_equal [ @owner.email_address ], (emails_from { request = request_from(requester) }).map(&:first)

      sent = emails_from { ItemRequestService.new(request).update_request(@owner, "accept", note: "Saturday?") }
      assert_equal [ requester.email_address ], sent.map(&:first)
      assert sent_to?(sent, requester, "accepted your request")

      sent = emails_from { ItemRequestService.new(request.reload).update_request(@owner, "complete") }
      assert_equal [ requester.email_address ], sent.map(&:first)
      assert sent_to?(sent, requester, "as complete")
    end

    it "emails the owner when the requester cancels or reopens, never the requester" do
      requester = member("changer")
      request = request_from(requester)

      sent = emails_from { ItemRequestService.new(request).cancel_request(requester, note: "Found one") }
      assert_equal [ @owner.email_address ], sent.map(&:first)
      assert sent_to?(sent, @owner, "Changer Tester cancelled their request")

      sent = emails_from { ItemRequestService.new(request.reload).update_request(requester, "uncancel") }
      assert_equal [ @owner.email_address ], sent.map(&:first)
      assert sent_to?(sent, @owner, "Changer Tester reopened their request")
    end

    it "sends nothing when the owner opens a request" do
      request = request_from(member("viewer"))
      assert_empty emails_from { ItemRequestService.new(request).update_request(@owner, "mark_as_viewed") }
    end

    it "emails each closed-out requester when the item is donated" do
      winner = request_from(member("winner"))
      other = member("other")
      request_from(other)
      ItemRequestService.new(winner).accept!

      sent = emails_from { ItemRequestService.new(winner.reload).complete! }
      assert sent_to?(sent, other, "was given to another requester")
    end

    it "emails each waiting requester when the owner deletes the item" do
      waiting = member("waiting")
      request_from(waiting)

      sent = emails_from { ItemService.new(@book).remove_item(@owner, note: "Water damage") }
      assert_equal [ waiting.email_address ], sent.map(&:first)
      assert sent_to?(sent, waiting, "so your request is closed")
    end

    it "sends nothing for a change that rolls back" do
      request = request_from(member("rollback"))
      ActionMailer::Base.deliveries.clear
      assert_no_enqueued_jobs(only: RequestEventNotificationJob) do
        ActiveRecord::Base.transaction do
          ItemRequestService.new(request).accept!
          raise ActiveRecord::Rollback
        end
      end
    end
  end

  describe "wishes" do
    def wish
      book = Book.create!(user_id: nil, title: "Emailed Wish", author: "Author", genre: "Fiction", published_year: 2020,
        summary: "Summary text long enough for validations on the book model here.", status: "wishlist")
      GroupItemAvailability.create!(item: book, community_group: @group)
      book
    end

    it "emails nobody about a wisher's own events while no one has offered the wish" do
      item = wish
      wisher = member("wisher")
      request = nil
      assert_empty emails_from { request = request_from(wisher, item) }
      assert_empty emails_from { ItemRequestService.new(request).cancel_request(wisher) }
    end

    it "emails the wisher once when a donor offers the wish" do
      item = wish
      wisher = member("hopeful")
      request_from(wisher, item)

      sent = emails_from { ItemService.new(item).fulfill_wishlist_item(@owner, { condition: "good" }) }
      assert_equal 1, sent.count { |to, _| to == wisher.email_address }
    end
  end

  describe "the other open requesters" do
    it "are told someone else was chosen, and then that the item is available again" do
      chosen = request_from(member("chosen"))
      waiting = member("waiter")
      request_from(waiting)

      assert sent_to?(emails_from { ItemRequestService.new(chosen).accept! }, waiting, "The owner accepted another request")
      sent = emails_from { ItemRequestService.new(chosen.reload).update_request(@owner, "decline") }
      assert sent_to?(sent, waiting, "available again")
    end

    it "hear the item is available again when the accepted requester cancels" do
      chosen_user = member("quitter")
      chosen = request_from(chosen_user)
      waiting = member("patient")
      request_from(waiting)
      ItemRequestService.new(chosen).accept!

      sent = emails_from { ItemRequestService.new(chosen.reload).cancel_request(chosen_user) }
      assert sent_to?(sent, waiting, "available again")
      assert sent_to?(sent, @owner, "Quitter Tester cancelled their request")
    end

    it "skip a requester whose own request closed before the notice went out" do
      chosen = request_from(member("picked"))
      waiting_user = member("late")
      waiting = request_from(waiting_user)
      perform_enqueued_jobs

      ActionMailer::Base.deliveries.clear
      ItemRequestService.new(chosen).accept!
      # The waiting requester gives up before the "someone else was chosen" notice is sent.
      assert ItemRequestService.new(waiting.reload).cancel_request(waiting_user)
      perform_enqueued_jobs

      assert_not ActionMailer::Base.deliveries.any? { |mail| mail.to == [ waiting_user.email_address ] }
    end

    it "aren't told anything when a request that wasn't accepted is declined" do
      declined = request_from(member("declined"))
      waiting = member("bystander")
      request_from(waiting)

      sent = emails_from { ItemRequestService.new(declined).update_request(@owner, "decline") }
      assert_not sent.any? { |to, _| to == waiting.email_address }
    end
  end

  describe "duplicates" do
    it "never emails the same event twice, even if the job runs again" do
      requester = member("once")
      request = request_from(requester)
      ItemRequestService.new(request).accept!
      event = request.messages.transitions.order(:id).last
      perform_enqueued_jobs

      ActionMailer::Base.deliveries.clear
      perform_enqueued_jobs { RequestEventNotificationJob.perform_later(event.id) }
      assert_empty ActionMailer::Base.deliveries
      assert_equal 1, UserNotification.where(notifiable: event, kind: UserNotification::KIND_REQUEST_EVENT).count
    end

    it "records nothing when sending fails, so a retry still sends the email" do
      requester = member("retry")
      request = request_from(requester)
      ItemRequestService.new(request).accept!
      event = request.messages.transitions.order(:id).last
      ActionMailer::Base.deliveries.clear
      failing = Object.new
      def failing.deliver_now = raise(Net::ReadTimeout)

      RequestEventMailer.stub(:event_update, failing) do
        assert_raises(Net::ReadTimeout) { RequestEventNotificationJob.new.perform(event.id) }
      end
      assert_not UserNotification.exists?(notifiable: event, kind: UserNotification::KIND_REQUEST_EVENT)

      RequestEventNotificationJob.new.perform(event.id)
      assert_equal [ [ requester.email_address ] ], ActionMailer::Base.deliveries.map(&:to)
      assert UserNotification.exists?(notifiable: event, kind: UserNotification::KIND_REQUEST_EVENT)
    end

    it "retries when the mail server can't be reached" do
      request = request_from(member("busy"))
      ItemRequestService.new(request).accept!
      event = request.messages.transitions.order(:id).last
      failing = Object.new
      def failing.deliver_now = raise(Net::OpenTimeout)

      RequestEventMailer.stub(:event_update, failing) do
        assert_enqueued_with(job: RequestEventNotificationJob, args: [ event.id ]) do
          RequestEventNotificationJob.perform_now(event.id)
        end
      end
    end

    it "never sends the same notice twice" do
      chosen = request_from(member("first"))
      waiting = request_from(member("second"))
      ItemRequestService.new(chosen).accept!
      event = chosen.messages.transitions.order(:id).last
      perform_enqueued_jobs

      ActionMailer::Base.deliveries.clear
      perform_enqueued_jobs { RequestEventNotificationJob.perform_later(event.id, UserNotification::KIND_OTHER_CHOSEN, [ waiting.id ]) }
      assert_empty ActionMailer::Base.deliveries
    end
  end
end
