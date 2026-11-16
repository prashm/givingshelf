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

  def setup_book_for_request(book, groups: [ @other_group ], status: "available")
    ItemRequest.where(item: book).destroy_all
    GroupItemAvailability.where(item: book).delete_all
    groups.each { |group| GroupItemAvailability.create!(item: book, community_group: group) }
    book.update!(status: status)
    book
  end

  def create_item_request(book, requester: @requester, status: "pending")
    ItemRequest.create!(
      item: book,
      requester: requester,
      owner: @owner,
      message: "Test message that is long enough",
      status: status
    )
  end

  def create_other_requester
    User.create!(
      email_address: "other_requester_#{SecureRandom.hex(6)}@example.com",
      password_digest: BCrypt::Password.create("password123!"),
      verified: true
    )
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
      assert_equal "pending", result.status
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
      book = setup_book_for_request(items(:one), status: "donated")
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
        status: "pending"
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
    def setup_item_request(status: "pending")
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
      assert_equal "accepted", item_request.status
      assert_equal "requested", item_request.item.status
      assert service.errors.empty?
    end

    it "declines a request successfully" do
      item_request = setup_item_request
      service = ItemRequestService.new(item_request)

      result = service.update_request(@owner, "decline")

      assert result
      item_request.reload
      assert_equal "declined", item_request.status
      assert service.errors.empty?
    end

    it "completes an accepted request successfully" do
      item_request = setup_item_request(status: "accepted")
      item_request.item.update!(status: "requested")
      service = ItemRequestService.new(item_request)

      result = service.update_request(@owner, "complete")

      assert result
      item_request.reload
      assert_equal "completed", item_request.status
      assert_equal "donated", item_request.item.status
      assert service.errors.empty?
    end

    it "marks request as viewed successfully" do
      item_request = setup_item_request
      service = ItemRequestService.new(item_request)

      result = service.update_request(@owner, "mark_as_viewed")

      assert result
      item_request.reload
      assert_equal "in_review", item_request.status
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
      item_request = setup_item_request(status: "pending")
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
        status: "pending"
      )

      service = ItemRequestService.new(request1)
      service.update_request(@owner, "accept")

      request1.reload
      assert_equal "accepted", request1.status
      assert_equal "requested", book.reload.status
    end
  end

  describe "#cancel_request" do
    it "cancels a request successfully and preserves the record" do
      book = setup_book_for_request(items(:one))
      item_request = ItemRequest.create!(
        item: book,
        requester: @requester,
        owner: @owner,
        message: "Test message that is long enough",
        status: "pending"
      )
      service = ItemRequestService.new(item_request)

      result = service.cancel_request(@requester)

      assert result
      item_request.reload
      assert_equal "cancelled", item_request.status
      assert ItemRequest.exists?(item_request.id)
      assert service.errors.empty?
    end

    it "reverts item to Available when cancelling an accepted request" do
      book = setup_book_for_request(items(:one))
      item_request = ItemRequest.create!(
        item: book,
        requester: @requester,
        owner: @owner,
        message: "Test message that is long enough",
        status: "pending"
      )
      ItemRequestService.new(item_request).accept!
      service = ItemRequestService.new(item_request.reload)

      result = service.cancel_request(@requester)

      assert result
      item_request.reload
      assert_equal "cancelled", item_request.status
      assert_equal "available", book.reload.status
      assert service.errors.empty?
    end

    it "returns false and sets error when user is not authorized" do
      book = setup_book_for_request(items(:one))
      item_request = ItemRequest.create!(
        item: book,
        requester: @requester,
        owner: @owner,
        message: "Test message that is long enough",
        status: "pending"
      )
      # Use a different user (owner) trying to cancel requester's request
      service = ItemRequestService.new(item_request)

      result = service.cancel_request(@owner)

      assert_not result
      assert_includes service.errors.join(" "), "Not authorized"
      assert ItemRequest.exists?(item_request.id)
    end
  end

  describe "#update_request with uncancel" do
    it "uncancels a request when requester calls update_request with uncancel" do
      book = setup_book_for_request(items(:one))
      item_request = ItemRequest.create!(
        item: book,
        requester: @requester,
        owner: @owner,
        message: "Test message that is long enough",
        status: "pending"
      )
      ItemRequestService.new(item_request).cancel!
      service = ItemRequestService.new(item_request.reload)

      result = service.update_request(@requester, "uncancel")

      assert result
      item_request.reload
      assert_equal "pending", item_request.status
      assert service.errors.empty?
    end

    it "returns false when non-requester tries to uncancel" do
      book = setup_book_for_request(items(:one))
      item_request = ItemRequest.create!(
        item: book,
        requester: @requester,
        owner: @owner,
        message: "Test message that is long enough",
        status: "pending"
      )
      ItemRequestService.new(item_request).cancel!
      service = ItemRequestService.new(item_request.reload)

      result = service.update_request(@owner, "uncancel")

      assert_not result
      assert_includes service.errors.join(" "), "Not authorized"
      item_request.reload
      assert_equal "cancelled", item_request.status
    end
  end

  describe "#accept!" do
    it "raises when accepting a cancelled request" do
      book = setup_book_for_request(items(:one))
      item_request = ItemRequest.create!(
        item: book,
        requester: @requester,
        owner: @owner,
        message: "Test message that is long enough",
        status: "pending"
      )
      service = ItemRequestService.new(item_request)
      service.cancel!

      error = assert_raises(RuntimeError) { service.accept! }
      assert_equal "Cannot accept a cancelled request", error.message
    end

    it "marks other pending requests for the same item as in review" do
      book = setup_book_for_request(items(:one))
      other_requester = User.create!(
        email_address: "other_requester_#{SecureRandom.hex(6)}@example.com",
        password_digest: BCrypt::Password.create("password123!"),
        verified: true
      )

      request1 = ItemRequest.create!(
        item: book,
        requester: @requester,
        owner: @owner,
        message: "First request message that is long enough",
        status: "pending"
      )
      request2 = ItemRequest.create!(
        item: book,
        requester: other_requester,
        owner: @owner,
        message: "Second request message that is long enough",
        status: "pending"
      )

      ItemRequestService.new(request1).accept!

      assert_equal "in_review", request2.reload.status
    end
  end

  describe "#decline!" do
    it "raises when declining a cancelled request" do
      book = setup_book_for_request(items(:one))
      item_request = ItemRequest.create!(
        item: book,
        requester: @requester,
        owner: @owner,
        message: "Test message that is long enough",
        status: "pending"
      )
      service = ItemRequestService.new(item_request)
      service.cancel!

      error = assert_raises(RuntimeError) { service.decline! }
      assert_equal "Cannot decline a cancelled request", error.message
    end
  end

  describe "#complete!" do
    it "raises when completing a cancelled request" do
      book = setup_book_for_request(items(:one))
      item_request = ItemRequest.create!(
        item: book,
        requester: @requester,
        owner: @owner,
        message: "Test message that is long enough",
        status: "pending"
      )
      service = ItemRequestService.new(item_request)
      service.cancel!

      error = assert_raises(RuntimeError) { service.complete! }
      assert_equal "Cannot complete a cancelled request", error.message
    end
  end

  describe "#cancel!" do
    it "raises when cancelling a completed request" do
      book = setup_book_for_request(items(:one))
      item_request = ItemRequest.create!(
        item: book,
        requester: @requester,
        owner: @owner,
        message: "Test message that is long enough",
        status: "pending"
      )
      service = ItemRequestService.new(item_request)
      service.accept!
      service.complete!

      error = assert_raises(RuntimeError) { service.cancel! }
      assert_equal "Cannot cancel a completed request", error.message
    end
  end

  describe "#uncancel!" do
    it "raises when uncancelling a request that is not cancelled" do
      book = setup_book_for_request(items(:one))
      item_request = ItemRequest.create!(
        item: book,
        requester: @requester,
        owner: @owner,
        message: "Test message that is long enough",
        status: "pending"
      )
      service = ItemRequestService.new(item_request)

      error = assert_raises(RuntimeError) { service.uncancel! }
      assert_equal "Can only uncancel a cancelled request", error.message
    end
  end

  describe "#mark_as_in_review!" do
    it "does nothing when request is not pending" do
      book = setup_book_for_request(items(:one))
      item_request = ItemRequest.create!(
        item: book,
        requester: @requester,
        owner: @owner,
        message: "Test message that is long enough",
        status: "accepted"
      )
      service = ItemRequestService.new(item_request)

      service.mark_as_in_review!

      assert_equal "accepted", item_request.reload.status
    end
  end

  describe "#match_wishlist_donor!" do
    it "moves a pending request to in review and assigns the donor as owner" do
      wishlist_book = Book.create!(
        user_id: nil,
        title: "Wishlist Match Book",
        author: "Author",
        summary: "Summary text long enough for validations on the book model here.",
        published_year: 2020,
        genre: "Fiction",
        status: "wishlist"
      )
      item_request = ItemRequest.create!(
        item: wishlist_book,
        requester: @requester,
        owner: nil,
        message: "I would love this book if anyone in the community has a copy.",
        status: "pending"
      )
      donor = @owner
      service = ItemRequestService.new(item_request)

      service.match_wishlist_donor!(donor)

      item_request.reload
      assert_equal "in_review", item_request.status
      assert_equal donor.id, item_request.owner_id
    end

    it "does nothing when request is not pending" do
      book = setup_book_for_request(items(:one))
      item_request = ItemRequest.create!(
        item: book,
        requester: @requester,
        owner: @owner,
        message: "Test message that is long enough",
        status: "declined"
      )
      service = ItemRequestService.new(item_request)

      service.match_wishlist_donor!(@owner)

      item_request.reload
      assert_equal "declined", item_request.status
    end
  end

  describe "state transitions without an item_request" do
    it "raises ArgumentError instead of NoMethodError" do
      %i[accept! decline! complete! cancel! uncancel! mark_as_in_review!].each do |transition|
        error = assert_raises(ArgumentError) { ItemRequestService.new.public_send(transition) }
        assert_equal "item_request is required", error.message
      end
      assert_raises(ArgumentError) { ItemRequestService.new.match_wishlist_donor!(@owner) }
    end
  end

  describe "#accept! sibling handling" do
    it "does not change declined, cancelled or completed sibling requests" do
      book = setup_book_for_request(items(:one))
      request = create_item_request(book)
      declined = create_item_request(book, requester: create_other_requester, status: "declined")
      cancelled = create_item_request(book, requester: create_other_requester, status: "cancelled")
      completed = create_item_request(book, requester: create_other_requester, status: "completed")
      pending = create_item_request(book, requester: create_other_requester)

      ItemRequestService.new(request).accept!

      assert_equal "declined", declined.reload.status
      assert_equal "cancelled", cancelled.reload.status
      assert_equal "completed", completed.reload.status
      assert_equal "in_review", pending.reload.status
    end
  end

  describe "transaction rollback" do
    it "rolls back accept! when the item update fails" do
      book = setup_book_for_request(items(:one))
      request = create_item_request(book)
      sibling = create_item_request(book, requester: create_other_requester)

      request.item.stub(:update!, ->(*) { raise ActiveRecord::RecordNotSaved, "item save failed" }) do
        assert_raises(ActiveRecord::RecordNotSaved) { ItemRequestService.new(request).accept! }
      end

      assert_equal "pending", request.reload.status
      assert_equal "pending", sibling.reload.status
      assert_equal "available", book.reload.status
    end

    it "rolls back complete! when the item update fails" do
      book = setup_book_for_request(items(:one))
      request = create_item_request(book)
      ItemRequestService.new(request).accept!

      request.item.stub(:update!, ->(*) { raise ActiveRecord::RecordNotSaved, "item save failed" }) do
        assert_raises(ActiveRecord::RecordNotSaved) { ItemRequestService.new(request).complete! }
      end

      assert_equal "accepted", request.reload.status
      assert_equal "requested", book.reload.status
    end

    it "rolls back cancel! of an accepted request when the request update fails" do
      book = setup_book_for_request(items(:one))
      request = create_item_request(book)
      ItemRequestService.new(request).accept!

      request.stub(:update!, ->(*) { raise ActiveRecord::RecordNotSaved, "request save failed" }) do
        assert_raises(ActiveRecord::RecordNotSaved) { ItemRequestService.new(request).cancel! }
      end

      assert_equal "accepted", request.reload.status
      assert_equal "requested", book.reload.status
    end

    it "reports the error and leaves state untouched when update_request accept fails" do
      book = setup_book_for_request(items(:one))
      request = create_item_request(book)
      service = ItemRequestService.new(request)

      request.item.stub(:update!, ->(*) { raise ActiveRecord::RecordNotSaved, "item save failed" }) do
        assert_equal false, service.update_request(@owner, "accept")
      end

      assert_includes service.errors, "item save failed"
      assert_equal "pending", request.reload.status
    end
  end

  describe "transition happy paths" do
    it "decline! declines a pending request" do
      book = setup_book_for_request(items(:one))
      request = create_item_request(book)

      ItemRequestService.new(request).decline!

      assert_equal "declined", request.reload.status
    end

    it "mark_as_in_review! moves a pending request to in review" do
      book = setup_book_for_request(items(:one))
      request = create_item_request(book)

      ItemRequestService.new(request).mark_as_in_review!

      assert_equal "in_review", request.reload.status
    end

    it "uncancel! moves a cancelled request back to pending" do
      book = setup_book_for_request(items(:one))
      request = create_item_request(book, status: "cancelled")

      ItemRequestService.new(request).uncancel!

      assert_equal "pending", request.reload.status
    end

    it "complete! raises on a pending request" do
      book = setup_book_for_request(items(:one))
      request = create_item_request(book)

      error = assert_raises(RuntimeError) { ItemRequestService.new(request).complete! }
      assert_equal "Can only complete an accepted request", error.message
      assert_equal "available", book.reload.status
    end

    it "cancel! on a pending request leaves the item status unchanged" do
      book = setup_book_for_request(items(:one))
      request = create_item_request(book)

      ItemRequestService.new(request).cancel!

      assert_equal "cancelled", request.reload.status
      assert_equal "available", book.reload.status
    end
  end

  describe "#requests_for_user" do
    it "returns received requests for user" do
      # Isolate from fixture requests (e.g. toy_request_one) so we only count the 2 we create
      ItemRequest.where(owner: @owner).destroy_all

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
        status: "available"
      )
      setup_book_for_request(book2)

      request1 = ItemRequest.create!(
        item: book1,
        requester: @requester,
        owner: @owner,
        message: "First request message that is long enough",
        status: "pending"
      )
      request2 = ItemRequest.create!(
        item: book2,
        requester: @requester,
        owner: @owner,
        message: "Second request message that is long enough",
        status: "pending"
      )

      requests = service.requests_for_user(@owner, "received")

      assert_includes requests.map(&:id), request1.id
      assert_includes requests.map(&:id), request2.id
      assert_equal 2, requests.count
      # Should be ordered by created_at desc
      assert_equal request2.id, requests.first.id
    end

    it "returns sent requests for user" do
      # Isolate from fixture requests (e.g. toy_request_one) so we only count the 2 we create
      ItemRequest.where(requester: @requester).destroy_all

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
        status: "available"
      )
      setup_book_for_request(book2)

      request1 = ItemRequest.create!(
        item: book1,
        requester: @requester,
        owner: @owner,
        message: "First request message that is long enough",
        status: "pending"
      )
      request2 = ItemRequest.create!(
        item: book2,
        requester: @requester,
        owner: @owner,
        message: "Second request message that is long enough",
        status: "pending"
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
        status: "pending"
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
        status: "pending"
      )


      json = service.request_json(item_request)

      assert json[:book].is_a?(Hash)
      assert_equal book.id, json[:book][:id]
      assert_equal book.title, json[:book][:title]
    end
  end

  describe "#display_status" do
    it "returns 'Completed' for completed" do
      assert_equal "Completed", service.display_status("completed")
    end

    it "returns 'Accepted' for accepted" do
      assert_equal "Accepted", service.display_status("accepted")
    end

    it "returns 'Declined' for declined" do
      assert_equal "Declined", service.display_status("declined")
    end

    it "returns 'In Review' for in_review" do
      assert_equal "In Review", service.display_status("in_review")
    end

    it "returns 'Pending' for pending" do
      assert_equal "Pending", service.display_status("pending")
    end

    it "returns 'Cancelled' for cancelled" do
      assert_equal "Cancelled", service.display_status("cancelled")
    end

    it "returns 'Pending' for unknown status" do
      assert_equal "Pending", service.display_status("unknown")
    end
  end

  def remove_user_from_group(user, group)
    CommunityGroupMembership.where(user: user, community_group: group).delete_all
  end
end
