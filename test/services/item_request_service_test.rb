require "test_helper"
require "minitest/spec"

class ItemRequestServiceTest < ActiveSupport::TestCase
  include ActiveJob::TestHelper
  extend Minitest::Spec::DSL

  def service
    @service ||= ItemRequestService.new
  end

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
    ItemRequest.where(item: book).destroy_all
    GroupItemAvailability.where(item: book).delete_all
    groups.each { |group| GroupItemAvailability.create!(item: book, community_group: group) }
    book.update!(status: status)
    book
  end

  def add_user_to_group(user, group, auto_joined: false)
    CommunityGroupMembership.find_or_create_by!(user: user, community_group: group) do |m|
      m.admin = false
      m.auto_joined = auto_joined
    end
  end

  describe "#create_request" do
    it "creates a request successfully" do
      book = setup_book_for_request(items(:one))
      message = "I would love to read this book!"

      result = service.create_request(@requester, book.id, message)

      assert result
      assert result.persisted?
      assert_equal @requester, result.requester
      assert_equal book, result.item
      assert_equal message, result.message
      assert_equal ItemRequest::PENDING_STATUS, result.status
      assert service.errors.empty?
    end

    it "notifies book owner when request is created" do
      book = setup_book_for_request(items(:one))
      message = "I would love to read this book!"

      assert_enqueued_jobs(1, only: ItemRequestNotificationJob) do
        service.create_request(@requester, book.id, message)
      end
    end

    it "returns nil and sets error when user profile is incomplete" do
      book = setup_book_for_request(items(:one))
      message = "I would love to read this book!"

      @requester.stub(:profile_complete?, false) do
        result = service.create_request(@requester, book.id, message)

        assert_nil result
        assert_includes service.errors.join(" "), "User profile is incomplete"
      end
    end

    it "returns nil and sets error when book cannot be requested - user is owner" do
      book = setup_book_for_request(items(:one))
      message = "I would love to read this book!"


      result = service.create_request(@owner, book.id, message)

      assert_nil result
      assert_includes service.errors.join(" "), "Cannot request this item"
    end

    it "returns nil and sets error when book cannot be requested - book not available" do
      book = setup_book_for_request(items(:one), status: BookStatus::DONATED)
      message = "I would love to read this book!"


      result = service.create_request(@requester, book.id, message)

      assert_nil result
      assert_includes service.errors.join(" "), "Cannot request this item"
    end

    it "returns nil and sets error when book cannot be requested - user not in groups" do
      book = setup_book_for_request(items(:one))
      message = "I would love to read this book!"
      remove_user_from_group(@requester, @other_group)


      result = service.create_request(@requester, book.id, message)

      assert_nil result
      assert_includes service.errors.join(" "), "Cannot request this item"
      assert_includes service.errors.join(" "), "not a member of any groups"
    end

    it "returns nil and sets error when book cannot be requested - pending request exists" do
      book = setup_book_for_request(items(:one))
      message = "I would love to read this book!"
      # Create an existing pending request
      ItemRequest.create!(
        item: book,
        requester: @requester,
        owner: @owner,
        message: "Previous request message that is long enough",
        status: ItemRequest::PENDING_STATUS
      )


      result = service.create_request(@requester, book.id, message)

      assert_nil result
      assert_includes service.errors.join(" "), "Cannot request this item"
      assert_includes service.errors.join(" "), "You already requested this item"
    end

    it "returns nil and sets error when message is too short" do
      book = setup_book_for_request(items(:one))
      message = "Short"


      result = service.create_request(@requester, book.id, message)

      assert_nil result
      assert_not service.errors.empty?
      assert_includes service.errors.join(" "), "too short"
    end

    it "returns nil and sets error when message is too long" do
      book = setup_book_for_request(items(:one))
      message = "x" * 501


      result = service.create_request(@requester, book.id, message)

      assert_nil result
      assert_not service.errors.empty?
      assert_includes service.errors.join(" "), "too long"
    end

    it "returns nil when book does not exist" do
      message = "I would love to read this book!"


      result = service.create_request(@requester, 99999, message)

      assert_nil result
      assert_not service.errors.empty?
    end
  end

  describe "#update_request" do
    def setup_item_request(status: ItemRequest::PENDING_STATUS)
      book = setup_book_for_request(items(:one))
      ItemRequest.create!(
        item: book,
        requester: @requester,
        owner: @owner,
        message: "Test message that is long enough",
        status: status
      )
    end

    it "accepts a request successfully" do
      item_request = setup_item_request
      service = ItemRequestService.new(item_request)

      result = service.update_request(@owner, "accept")

      assert result
      item_request.reload
      assert_equal ItemRequest::ACCEPTED_STATUS, item_request.status
      assert_equal BookStatus::REQUESTED, item_request.item.status
      assert service.errors.empty?
    end

    it "declines a request successfully" do
      item_request = setup_item_request
      service = ItemRequestService.new(item_request)

      result = service.update_request(@owner, "decline")

      assert result
      item_request.reload
      assert_equal ItemRequest::DECLINED_STATUS, item_request.status
      assert service.errors.empty?
    end

    it "completes an accepted request successfully" do
      item_request = setup_item_request(status: ItemRequest::ACCEPTED_STATUS)
      item_request.item.update!(status: BookStatus::REQUESTED)
      service = ItemRequestService.new(item_request)

      result = service.update_request(@owner, "complete")

      assert result
      item_request.reload
      assert_equal ItemRequest::COMPLETED_STATUS, item_request.status
      assert_equal BookStatus::DONATED, item_request.item.status
      assert service.errors.empty?
    end

    it "marks request as viewed successfully" do
      item_request = setup_item_request
      service = ItemRequestService.new(item_request)

      result = service.update_request(@owner, "mark_as_viewed")

      assert result
      item_request.reload
      assert_equal ItemRequest::IN_REVIEW_STATUS, item_request.status
      assert service.errors.empty?
    end

    it "returns false and sets error when action is invalid" do
      item_request = setup_item_request
      service = ItemRequestService.new(item_request)

      result = service.update_request(@owner, "invalid_action")

      assert_not result
      assert_includes service.errors.join(" "), "Invalid action"
    end

    it "returns false and sets error when user is not authorized" do
      item_request = setup_item_request
      unauthorized_user = users(:two)
      service = ItemRequestService.new(item_request)

      result = service.update_request(unauthorized_user, "accept")

      assert_not result
      assert_includes service.errors.join(" "), "Not authorized"
    end

    it "returns false when trying to complete a non-accepted request" do
      item_request = setup_item_request(status: ItemRequest::PENDING_STATUS)
      service = ItemRequestService.new(item_request)

      result = service.update_request(@owner, "complete")

      assert_not result
      assert_includes service.errors.join(" "), "Can only complete an accepted request"
    end

    it "updates book status to REQUESTED when accepting a request" do
      book = setup_book_for_request(items(:one))
      request1 = ItemRequest.create!(
        item: book,
        requester: @requester,
        owner: @owner,
        message: "First request message that is long enough",
        status: ItemRequest::PENDING_STATUS
      )

      service = ItemRequestService.new(request1)
      service.update_request(@owner, "accept")

      request1.reload
      assert_equal ItemRequest::ACCEPTED_STATUS, request1.status
      assert_equal BookStatus::REQUESTED, book.reload.status
    end
  end

  describe "#cancel_request" do
    it "cancels a request successfully" do
      book = setup_book_for_request(items(:one))
      item_request = ItemRequest.create!(
        item: book,
        requester: @requester,
        owner: @owner,
        message: "Test message that is long enough",
        status: ItemRequest::PENDING_STATUS
      )
      service = ItemRequestService.new(item_request)

      result = service.cancel_request(@requester)

      assert result
      assert_nil ItemRequest.find_by(id: item_request.id)
      assert service.errors.empty?
    end

    it "returns false and sets error when user is not authorized" do
      book = setup_book_for_request(items(:one))
      item_request = ItemRequest.create!(
        item: book,
        requester: @requester,
        owner: @owner,
        message: "Test message that is long enough",
        status: ItemRequest::PENDING_STATUS
      )
      # Use a different user (owner) trying to cancel requester's request
      service = ItemRequestService.new(item_request)

      result = service.cancel_request(@owner)

      assert_not result
      assert_includes service.errors.join(" "), "Not authorized"
      assert ItemRequest.exists?(item_request.id)
    end
  end

  describe "#requests_for_user" do
    it "returns received requests for user" do
      # Both books should be owned by @owner to test "received" requests
      book1 = setup_book_for_request(items(:one))
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

      request1 = ItemRequest.create!(
        item: book1,
        requester: @requester,
        owner: @owner,
        message: "First request message that is long enough",
        status: ItemRequest::PENDING_STATUS
      )
      request2 = ItemRequest.create!(
        item: book2,
        requester: @requester,
        owner: @owner,
        message: "Second request message that is long enough",
        status: ItemRequest::PENDING_STATUS
      )

      requests = service.requests_for_user(@owner, "received")

      assert_includes requests.map(&:id), request1.id
      assert_includes requests.map(&:id), request2.id
      assert_equal 2, requests.count
      # Should be ordered by created_at desc
      assert_equal request2.id, requests.first.id
    end

    it "returns sent requests for user" do
      # Both books should be owned by @owner, and @requester sends requests
      book1 = setup_book_for_request(items(:one))
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

      request1 = ItemRequest.create!(
        item: book1,
        requester: @requester,
        owner: @owner,
        message: "First request message that is long enough",
        status: ItemRequest::PENDING_STATUS
      )
      request2 = ItemRequest.create!(
        item: book2,
        requester: @requester,
        owner: @owner,
        message: "Second request message that is long enough",
        status: ItemRequest::PENDING_STATUS
      )


      requests = service.requests_for_user(@requester, "sent")

      assert_includes requests.map(&:id), request1.id
      assert_includes requests.map(&:id), request2.id
      assert_equal 2, requests.count
      # Should be ordered by created_at desc
      assert_equal request2.id, requests.first.id
    end

    it "returns empty array for unknown type" do
      requests = service.requests_for_user(@owner, "unknown")

      assert_equal [], requests
    end
  end

  describe "#request_json" do
    it "returns correct JSON structure" do
      book = setup_book_for_request(items(:one))
      item_request = ItemRequest.create!(
        item: book,
        requester: @requester,
        owner: @owner,
        message: "Test message that is long enough",
        status: ItemRequest::PENDING_STATUS
      )


      json = service.request_json(item_request)

      assert_equal item_request.id, json[:id]
      assert_equal item_request.status, json[:status]
      assert_equal "Pending", json[:status_display]
      assert_equal item_request.message, json[:message]
      assert_equal item_request.created_at, json[:created_at]
      assert_equal item_request.updated_at, json[:updated_at]
      assert json[:book].present?
      assert json[:can_update_status].present?
      assert_equal @requester.id, json[:requester][:id]
      assert_equal @requester.display_name, json[:requester][:name]
      assert_equal @requester.location, json[:requester][:location]
      assert_equal @requester.verified?, json[:requester][:verified]
    end

    it "includes book JSON in request JSON" do
      book = setup_book_for_request(items(:one))
      item_request = ItemRequest.create!(
        item: book,
        requester: @requester,
        owner: @owner,
        message: "Test message that is long enough",
        status: ItemRequest::PENDING_STATUS
      )


      json = service.request_json(item_request)

      assert json[:book].is_a?(Hash)
      assert_equal book.id, json[:book][:id]
      assert_equal book.title, json[:book][:title]
    end
  end

  describe "#display_status" do
    it "returns 'Completed' for COMPLETED_STATUS" do
      assert_equal "Completed", service.display_status(ItemRequest::COMPLETED_STATUS)
    end

    it "returns 'Accepted' for ACCEPTED_STATUS" do
      assert_equal "Accepted", service.display_status(ItemRequest::ACCEPTED_STATUS)
    end

    it "returns 'Declined' for DECLINED_STATUS" do
      assert_equal "Declined", service.display_status(ItemRequest::DECLINED_STATUS)
    end

    it "returns 'In Review' for IN_REVIEW_STATUS" do
      assert_equal "In Review", service.display_status(ItemRequest::IN_REVIEW_STATUS)
    end

    it "returns 'Pending' for PENDING_STATUS" do
      assert_equal "Pending", service.display_status(ItemRequest::PENDING_STATUS)
    end

    it "returns 'Pending' for unknown status" do
      assert_equal "Pending", service.display_status(999)
    end
  end

  def remove_user_from_group(user, group)
    CommunityGroupMembership.where(user: user, community_group: group).delete_all
  end
end
