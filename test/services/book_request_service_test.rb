require "test_helper"
require "minitest/spec"

class BookRequestServiceTest < ActiveSupport::TestCase
  include ActiveJob::TestHelper
  extend Minitest::Spec::DSL

  def setup
    @owner = users(:one)
    @requester = users(:two)
    @zip_group = CommunityGroup.find_or_create_zipcode_group!
    @other_group = community_groups(:one)

    # Ensure owner and requester are in groups
    CommunityGroupMembership.find_or_create_by!(user: @owner, community_group: @other_group) do |m|
      m.admin = false
      m.auto_joined = false
    end
    CommunityGroupMembership.find_or_create_by!(user: @requester, community_group: @other_group) do |m|
      m.admin = false
      m.auto_joined = false
    end
  end

  private

  def setup_book_for_request(book, groups: [ @other_group ], status: BookStatus::AVAILABLE)
    BookRequest.where(book: book).destroy_all
    GroupBookAvailability.where(book: book).delete_all
    groups.each { |group| GroupBookAvailability.create!(book: book, community_group: group) }
    book.update!(status: status)
    book
  end

  def add_user_to_group(user, group, auto_joined: false)
    CommunityGroupMembership.find_or_create_by!(user: user, community_group: group) do |m|
      m.admin = false
      m.auto_joined = auto_joined
    end
  end

  describe "#initialize" do
    it "initializes with no book_request" do
      service = BookRequestService.new
      assert_nil service.book_request
      assert_equal [], service.errors
    end

    it "initializes with a book_request" do
      book_request = book_requests(:one)
      service = BookRequestService.new(book_request)
      assert_equal book_request, service.book_request
      assert_equal [], service.errors
    end
  end

  describe "#create_request" do
    it "creates a request successfully" do
      book = setup_book_for_request(books(:one))
      message = "I would love to read this book!"

      service = BookRequestService.new
      result = service.create_request(@requester, book.id, message)

      assert result
      assert result.persisted?
      assert_equal @requester, result.requester
      assert_equal book, result.book
      assert_equal message, result.message
      assert_equal BookRequest::PENDING_STATUS, result.status
      assert service.errors.empty?
    end

    it "notifies book owner when request is created" do
      book = setup_book_for_request(books(:one))
      message = "I would love to read this book!"

      assert_enqueued_jobs(1, only: BookRequestNotificationJob) do
        service = BookRequestService.new
        service.create_request(@requester, book.id, message)
      end
    end

    it "returns nil and sets error when user profile is incomplete" do
      book = setup_book_for_request(books(:one))
      message = "I would love to read this book!"

      @requester.stub(:profile_complete?, false) do
        service = BookRequestService.new
        result = service.create_request(@requester, book.id, message)

        assert_nil result
        assert_includes service.errors.join(" "), "User profile is incomplete"
      end
    end

    it "returns nil and sets error when book cannot be requested - user is owner" do
      book = setup_book_for_request(books(:one))
      message = "I would love to read this book!"

      service = BookRequestService.new
      result = service.create_request(@owner, book.id, message)

      assert_nil result
      assert_includes service.errors.join(" "), "Cannot request this book"
    end

    it "returns nil and sets error when book cannot be requested - book not available" do
      book = setup_book_for_request(books(:one), status: BookStatus::DONATED)
      message = "I would love to read this book!"

      service = BookRequestService.new
      result = service.create_request(@requester, book.id, message)

      assert_nil result
      assert_includes service.errors.join(" "), "Cannot request this book"
    end

    it "returns nil and sets error when book cannot be requested - user not in groups" do
      book = setup_book_for_request(books(:one))
      message = "I would love to read this book!"
      remove_user_from_group(@requester, @other_group)

      service = BookRequestService.new
      result = service.create_request(@requester, book.id, message)

      assert_nil result
      assert_includes service.errors.join(" "), "Cannot request this book"
      assert_includes service.errors.join(" "), "not a member of any groups"
    end

    it "returns nil and sets error when book cannot be requested - pending request exists" do
      book = setup_book_for_request(books(:one))
      message = "I would love to read this book!"
      # Create an existing pending request
      BookRequest.create!(
        book: book,
        requester: @requester,
        owner: @owner,
        message: "Previous request message that is long enough",
        status: BookRequest::PENDING_STATUS
      )

      service = BookRequestService.new
      result = service.create_request(@requester, book.id, message)

      assert_nil result
      assert_includes service.errors.join(" "), "Cannot request this book"
      assert_includes service.errors.join(" "), "pending or accepted request"
    end

    it "returns nil and sets error when message is too short" do
      book = setup_book_for_request(books(:one))
      message = "Short"

      service = BookRequestService.new
      result = service.create_request(@requester, book.id, message)

      assert_nil result
      assert_not service.errors.empty?
      assert_includes service.errors.join(" "), "too short"
    end

    it "returns nil and sets error when message is too long" do
      book = setup_book_for_request(books(:one))
      message = "x" * 501

      service = BookRequestService.new
      result = service.create_request(@requester, book.id, message)

      assert_nil result
      assert_not service.errors.empty?
      assert_includes service.errors.join(" "), "too long"
    end

    it "returns nil when book does not exist" do
      message = "I would love to read this book!"

      service = BookRequestService.new
      result = service.create_request(@requester, 99999, message)

      assert_nil result
      assert_not service.errors.empty?
    end
  end

  describe "#update_request" do
    def setup_book_request(status: BookRequest::PENDING_STATUS)
      book = setup_book_for_request(books(:one))
      BookRequest.create!(
        book: book,
        requester: @requester,
        owner: @owner,
        message: "Test message that is long enough",
        status: status
      )
    end

    it "accepts a request successfully" do
      book_request = setup_book_request
      service = BookRequestService.new(book_request)

      result = service.update_request(@owner, "accept")

      assert result
      book_request.reload
      assert_equal BookRequest::ACCEPTED_STATUS, book_request.status
      assert_equal BookStatus::REQUESTED, book_request.book.status
      assert service.errors.empty?
    end

    it "declines a request successfully" do
      book_request = setup_book_request
      service = BookRequestService.new(book_request)

      result = service.update_request(@owner, "decline")

      assert result
      book_request.reload
      assert_equal BookRequest::DECLINED_STATUS, book_request.status
      assert service.errors.empty?
    end

    it "completes an accepted request successfully" do
      book_request = setup_book_request(status: BookRequest::ACCEPTED_STATUS)
      book_request.book.update!(status: BookStatus::REQUESTED)
      service = BookRequestService.new(book_request)

      result = service.update_request(@owner, "complete")

      assert result
      book_request.reload
      assert_equal BookRequest::COMPLETED_STATUS, book_request.status
      assert_equal BookStatus::DONATED, book_request.book.status
      assert service.errors.empty?
    end

    it "marks request as viewed successfully" do
      book_request = setup_book_request
      service = BookRequestService.new(book_request)

      result = service.update_request(@owner, "mark_as_viewed")

      assert result
      book_request.reload
      assert_equal BookRequest::IN_REVIEW_STATUS, book_request.status
      assert service.errors.empty?
    end

    it "returns false and sets error when action is invalid" do
      book_request = setup_book_request
      service = BookRequestService.new(book_request)

      result = service.update_request(@owner, "invalid_action")

      assert_not result
      assert_includes service.errors.join(" "), "Invalid action"
    end

    it "returns false and sets error when user is not authorized" do
      book_request = setup_book_request
      unauthorized_user = users(:two)
      service = BookRequestService.new(book_request)

      result = service.update_request(unauthorized_user, "accept")

      assert_not result
      assert_includes service.errors.join(" "), "Not authorized"
    end

    it "returns false when trying to complete a non-accepted request" do
      book_request = setup_book_request(status: BookRequest::PENDING_STATUS)
      service = BookRequestService.new(book_request)

      result = service.update_request(@owner, "complete")

      assert_not result
      assert_includes service.errors.join(" "), "Can only complete an accepted request"
    end

    it "updates book status to REQUESTED when accepting a request" do
      book = setup_book_for_request(books(:one))
      request1 = BookRequest.create!(
        book: book,
        requester: @requester,
        owner: @owner,
        message: "First request message that is long enough",
        status: BookRequest::PENDING_STATUS
      )

      service = BookRequestService.new(request1)
      service.update_request(@owner, "accept")

      request1.reload
      assert_equal BookRequest::ACCEPTED_STATUS, request1.status
      assert_equal BookStatus::REQUESTED, book.reload.status
    end
  end

  describe "#cancel_request" do
    it "cancels a request successfully" do
      book = setup_book_for_request(books(:one))
      book_request = BookRequest.create!(
        book: book,
        requester: @requester,
        owner: @owner,
        message: "Test message that is long enough",
        status: BookRequest::PENDING_STATUS
      )
      service = BookRequestService.new(book_request)

      result = service.cancel_request(@requester)

      assert result
      assert_nil BookRequest.find_by(id: book_request.id)
      assert service.errors.empty?
    end

    it "returns false and sets error when user is not authorized" do
      book = setup_book_for_request(books(:one))
      book_request = BookRequest.create!(
        book: book,
        requester: @requester,
        owner: @owner,
        message: "Test message that is long enough",
        status: BookRequest::PENDING_STATUS
      )
      # Use a different user (owner) trying to cancel requester's request
      service = BookRequestService.new(book_request)

      result = service.cancel_request(@owner)

      assert_not result
      assert_includes service.errors.join(" "), "Not authorized"
      assert BookRequest.exists?(book_request.id)
    end
  end

  describe "#requests_for_user" do
    it "returns received requests for user" do
      # Both books should be owned by @owner to test "received" requests
      book1 = setup_book_for_request(books(:one))
      # Create a second book owned by @owner
      book2 = Book.create!(
        user: @owner,
        title: "Another Book",
        author: "Another Author",
        condition: "good",
        summary: "This is a test book summary that is long enough.",
        published_year: 2020,
        status: BookStatus::AVAILABLE
      )
      setup_book_for_request(book2)

      request1 = BookRequest.create!(
        book: book1,
        requester: @requester,
        owner: @owner,
        message: "First request message that is long enough",
        status: BookRequest::PENDING_STATUS
      )
      request2 = BookRequest.create!(
        book: book2,
        requester: @requester,
        owner: @owner,
        message: "Second request message that is long enough",
        status: BookRequest::PENDING_STATUS
      )

      service = BookRequestService.new
      requests = service.requests_for_user(@owner, "received")

      assert_includes requests.map(&:id), request1.id
      assert_includes requests.map(&:id), request2.id
      assert_equal 2, requests.count
      # Should be ordered by created_at desc
      assert_equal request2.id, requests.first.id
    end

    it "returns sent requests for user" do
      # Both books should be owned by @owner, and @requester sends requests
      book1 = setup_book_for_request(books(:one))
      # Create a second book owned by @owner
      book2 = Book.create!(
        user: @owner,
        title: "Yet Another Book",
        author: "Yet Another Author",
        condition: "good",
        summary: "This is a test book summary that is long enough.",
        published_year: 2020,
        status: BookStatus::AVAILABLE
      )
      setup_book_for_request(book2)

      request1 = BookRequest.create!(
        book: book1,
        requester: @requester,
        owner: @owner,
        message: "First request message that is long enough",
        status: BookRequest::PENDING_STATUS
      )
      request2 = BookRequest.create!(
        book: book2,
        requester: @requester,
        owner: @owner,
        message: "Second request message that is long enough",
        status: BookRequest::PENDING_STATUS
      )

      service = BookRequestService.new
      requests = service.requests_for_user(@requester, "sent")

      assert_includes requests.map(&:id), request1.id
      assert_includes requests.map(&:id), request2.id
      assert_equal 2, requests.count
      # Should be ordered by created_at desc
      assert_equal request2.id, requests.first.id
    end

    it "returns empty array for unknown type" do
      service = BookRequestService.new
      requests = service.requests_for_user(@owner, "unknown")

      assert_equal [], requests
    end
  end

  describe "#request_json" do
    it "returns correct JSON structure" do
      book = setup_book_for_request(books(:one))
      book_request = BookRequest.create!(
        book: book,
        requester: @requester,
        owner: @owner,
        message: "Test message that is long enough",
        status: BookRequest::PENDING_STATUS
      )

      service = BookRequestService.new
      json = service.request_json(book_request)

      assert_equal book_request.id, json[:id]
      assert_equal book_request.status, json[:status]
      assert_equal "Pending", json[:status_display]
      assert_equal book_request.message, json[:message]
      assert_equal book_request.created_at, json[:created_at]
      assert_equal book_request.updated_at, json[:updated_at]
      assert json[:book].present?
      assert json[:can_update_status].present?
      assert_equal @requester.id, json[:requester][:id]
      assert_equal @requester.display_name, json[:requester][:name]
      assert_equal @requester.location, json[:requester][:location]
      assert_equal @requester.verified?, json[:requester][:verified]
    end

    it "includes book JSON in request JSON" do
      book = setup_book_for_request(books(:one))
      book_request = BookRequest.create!(
        book: book,
        requester: @requester,
        owner: @owner,
        message: "Test message that is long enough",
        status: BookRequest::PENDING_STATUS
      )

      service = BookRequestService.new
      json = service.request_json(book_request)

      assert json[:book].is_a?(Hash)
      assert_equal book.id, json[:book][:id]
      assert_equal book.title, json[:book][:title]
    end
  end

  describe "#display_status" do
    it "returns 'Completed' for COMPLETED_STATUS" do
      service = BookRequestService.new
      assert_equal "Completed", service.display_status(BookRequest::COMPLETED_STATUS)
    end

    it "returns 'Accepted' for ACCEPTED_STATUS" do
      service = BookRequestService.new
      assert_equal "Accepted", service.display_status(BookRequest::ACCEPTED_STATUS)
    end

    it "returns 'Declined' for DECLINED_STATUS" do
      service = BookRequestService.new
      assert_equal "Declined", service.display_status(BookRequest::DECLINED_STATUS)
    end

    it "returns 'In Review' for IN_REVIEW_STATUS" do
      service = BookRequestService.new
      assert_equal "In Review", service.display_status(BookRequest::IN_REVIEW_STATUS)
    end

    it "returns 'Pending' for PENDING_STATUS" do
      service = BookRequestService.new
      assert_equal "Pending", service.display_status(BookRequest::PENDING_STATUS)
    end

    it "returns 'Pending' for unknown status" do
      service = BookRequestService.new
      assert_equal "Pending", service.display_status(999)
    end
  end

  def remove_user_from_group(user, group)
    CommunityGroupMembership.where(user: user, community_group: group).delete_all
  end
end
