require "test_helper"
require "minitest/spec"

class ItemRequestServiceTest < ActiveSupport::TestCase
  include ActiveJob::TestHelper
  include ActionCable::TestHelper
  include ActionMailer::TestHelper
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

  def setup_book_for_request(book, groups: [ @other_group ], status: ShareableItemStatus::AVAILABLE)
    ItemRequest.where(item: book).destroy_all
    GroupItemAvailability.where(item: book).delete_all
    groups.each { |group| GroupItemAvailability.create!(item: book, community_group: group) }
    book.update!(status: status)
    book
  end

  def create_item_request(book, requester: @requester, status: ItemRequest::PENDING_STATUS)
    ItemRequest.create!(
      item: book,
      requester: requester,
      owner: @owner,
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
      assert_equal message, result.initial_message.content
      assert_equal ItemRequest::PENDING_STATUS, result.status
      assert service.errors.empty?
    end

    it "emails the book owner, from the request's first event, when a request is created" do
      book = setup_book_for_request(items(:one))
      message = "I would love to read this book!"

      request = nil
      assert_enqueued_jobs(1, only: RequestEventNotificationJob) do
        request = service.create_request(@requester, book.id, message)
      end
      assert_enqueued_email_with ItemRequestMailer, :new_request_notification, args: [ request ] do
        perform_enqueued_jobs(only: RequestEventNotificationJob)
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
      book = setup_book_for_request(items(:one), status: ShareableItemStatus::DONATED)
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
      assert_equal ShareableItemStatus::REQUESTED, item_request.item.status
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
      item_request.item.update!(status: ShareableItemStatus::REQUESTED)
      service = ItemRequestService.new(item_request)

      result = service.update_request(@owner, "complete")

      assert result
      item_request.reload
      assert_equal ItemRequest::COMPLETED_STATUS, item_request.status
      assert_equal ShareableItemStatus::DONATED, item_request.item.status
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
        status: ItemRequest::PENDING_STATUS
      )

      service = ItemRequestService.new(request1)
      service.update_request(@owner, "accept")

      request1.reload
      assert_equal ItemRequest::ACCEPTED_STATUS, request1.status
      assert_equal ShareableItemStatus::REQUESTED, book.reload.status
    end
  end

  describe "#cancel_request" do
    it "cancels a request successfully and preserves the record" do
      book = setup_book_for_request(items(:one))
      item_request = ItemRequest.create!(
        item: book,
        requester: @requester,
        owner: @owner,
        status: ItemRequest::PENDING_STATUS
      )
      service = ItemRequestService.new(item_request)

      result = service.cancel_request(@requester)

      assert result
      item_request.reload
      assert_equal ItemRequest::CANCELLED_STATUS, item_request.status
      assert ItemRequest.exists?(item_request.id)
      assert service.errors.empty?
    end

    it "reverts item to Available when cancelling an accepted request" do
      book = setup_book_for_request(items(:one))
      item_request = ItemRequest.create!(
        item: book,
        requester: @requester,
        owner: @owner,
        status: ItemRequest::PENDING_STATUS
      )
      ItemRequestService.new(item_request).accept!
      service = ItemRequestService.new(item_request.reload)

      result = service.cancel_request(@requester)

      assert result
      item_request.reload
      assert_equal ItemRequest::CANCELLED_STATUS, item_request.status
      assert_equal ShareableItemStatus::AVAILABLE, book.reload.status
      assert service.errors.empty?
    end

    it "returns false and sets error when user is not authorized" do
      book = setup_book_for_request(items(:one))
      item_request = ItemRequest.create!(
        item: book,
        requester: @requester,
        owner: @owner,
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

  describe "#update_request with uncancel" do
    it "uncancels a request when requester calls update_request with uncancel" do
      book = setup_book_for_request(items(:one))
      item_request = ItemRequest.create!(
        item: book,
        requester: @requester,
        owner: @owner,
        status: ItemRequest::PENDING_STATUS
      )
      ItemRequestService.new(item_request).cancel!
      service = ItemRequestService.new(item_request.reload)

      result = service.update_request(@requester, "uncancel")

      assert result
      item_request.reload
      assert_equal ItemRequest::PENDING_STATUS, item_request.status
      assert service.errors.empty?
    end

    it "returns false when non-requester tries to uncancel" do
      book = setup_book_for_request(items(:one))
      item_request = ItemRequest.create!(
        item: book,
        requester: @requester,
        owner: @owner,
        status: ItemRequest::PENDING_STATUS
      )
      ItemRequestService.new(item_request).cancel!
      service = ItemRequestService.new(item_request.reload)

      result = service.update_request(@owner, "uncancel")

      assert_not result
      assert_includes service.errors.join(" "), "Not authorized"
      item_request.reload
      assert_equal ItemRequest::CANCELLED_STATUS, item_request.status
    end
  end

  describe "#accept!" do
    it "raises when accepting a cancelled request" do
      book = setup_book_for_request(items(:one))
      item_request = ItemRequest.create!(
        item: book,
        requester: @requester,
        owner: @owner,
        status: ItemRequest::PENDING_STATUS
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
        status: ItemRequest::PENDING_STATUS
      )
      request2 = ItemRequest.create!(
        item: book,
        requester: other_requester,
        owner: @owner,
        status: ItemRequest::PENDING_STATUS
      )

      ItemRequestService.new(request1).accept!

      assert_equal ItemRequest::IN_REVIEW_STATUS, request2.reload.status
    end
  end

  describe "#decline!" do
    it "raises when declining a cancelled request" do
      book = setup_book_for_request(items(:one))
      item_request = ItemRequest.create!(
        item: book,
        requester: @requester,
        owner: @owner,
        status: ItemRequest::PENDING_STATUS
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
        status: ItemRequest::PENDING_STATUS
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
        status: ItemRequest::PENDING_STATUS
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
        status: ItemRequest::PENDING_STATUS
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
        status: ItemRequest::ACCEPTED_STATUS
      )
      service = ItemRequestService.new(item_request)

      service.mark_as_in_review!

      assert_equal ItemRequest::ACCEPTED_STATUS, item_request.reload.status
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
        status: ShareableItemStatus::WISHLIST
      )
      item_request = ItemRequest.create!(
        item: wishlist_book,
        requester: @requester,
        owner: nil,
        status: ItemRequest::PENDING_STATUS
      )
      donor = @owner
      service = ItemRequestService.new(item_request)

      service.match_wishlist_donor!(donor)

      item_request.reload
      assert_equal ItemRequest::IN_REVIEW_STATUS, item_request.status
      assert_equal donor.id, item_request.owner_id
    end

    it "does nothing when request is not pending" do
      book = setup_book_for_request(items(:one))
      item_request = ItemRequest.create!(
        item: book,
        requester: @requester,
        owner: @owner,
        status: ItemRequest::DECLINED_STATUS
      )
      service = ItemRequestService.new(item_request)

      service.match_wishlist_donor!(@owner)

      item_request.reload
      assert_equal ItemRequest::DECLINED_STATUS, item_request.status
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
      declined = create_item_request(book, requester: create_other_requester, status: ItemRequest::DECLINED_STATUS)
      cancelled = create_item_request(book, requester: create_other_requester, status: ItemRequest::CANCELLED_STATUS)
      completed = create_item_request(book, requester: create_other_requester, status: ItemRequest::COMPLETED_STATUS)
      pending = create_item_request(book, requester: create_other_requester)

      ItemRequestService.new(request).accept!

      assert_equal ItemRequest::DECLINED_STATUS, declined.reload.status
      assert_equal ItemRequest::CANCELLED_STATUS, cancelled.reload.status
      assert_equal ItemRequest::COMPLETED_STATUS, completed.reload.status
      assert_equal ItemRequest::IN_REVIEW_STATUS, pending.reload.status
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

      assert_equal ItemRequest::PENDING_STATUS, request.reload.status
      assert_equal ItemRequest::PENDING_STATUS, sibling.reload.status
      assert_equal ShareableItemStatus::AVAILABLE, book.reload.status
    end

    it "rolls back complete! when the item update fails" do
      book = setup_book_for_request(items(:one))
      request = create_item_request(book)
      ItemRequestService.new(request).accept!

      request.item.stub(:update!, ->(*) { raise ActiveRecord::RecordNotSaved, "item save failed" }) do
        assert_raises(ActiveRecord::RecordNotSaved) { ItemRequestService.new(request).complete! }
      end

      assert_equal ItemRequest::ACCEPTED_STATUS, request.reload.status
      assert_equal ShareableItemStatus::REQUESTED, book.reload.status
    end

    it "rolls back cancel! of an accepted request when the request update fails" do
      book = setup_book_for_request(items(:one))
      request = create_item_request(book)
      ItemRequestService.new(request).accept!

      request.stub(:update!, ->(*) { raise ActiveRecord::RecordNotSaved, "request save failed" }) do
        assert_raises(ActiveRecord::RecordNotSaved) { ItemRequestService.new(request).cancel! }
      end

      assert_equal ItemRequest::ACCEPTED_STATUS, request.reload.status
      assert_equal ShareableItemStatus::REQUESTED, book.reload.status
    end

    it "reports the error and leaves state untouched when update_request accept fails" do
      book = setup_book_for_request(items(:one))
      request = create_item_request(book)
      service = ItemRequestService.new(request)

      request.item.stub(:update!, ->(*) { raise ActiveRecord::RecordNotSaved, "item save failed" }) do
        assert_equal false, service.update_request(@owner, "accept")
      end

      assert_includes service.errors, "item save failed"
      assert_equal ItemRequest::PENDING_STATUS, request.reload.status
    end
  end

  describe "transition happy paths" do
    it "decline! declines a pending request" do
      book = setup_book_for_request(items(:one))
      request = create_item_request(book)

      ItemRequestService.new(request).decline!

      assert_equal ItemRequest::DECLINED_STATUS, request.reload.status
    end

    it "mark_as_in_review! moves a pending request to in review" do
      book = setup_book_for_request(items(:one))
      request = create_item_request(book)

      ItemRequestService.new(request).mark_as_in_review!

      assert_equal ItemRequest::IN_REVIEW_STATUS, request.reload.status
    end

    it "uncancel! moves a cancelled request back to pending" do
      book = setup_book_for_request(items(:one))
      request = create_item_request(book, status: ItemRequest::CANCELLED_STATUS)

      ItemRequestService.new(request).uncancel!

      assert_equal ItemRequest::PENDING_STATUS, request.reload.status
    end

    it "complete! raises on a pending request" do
      book = setup_book_for_request(items(:one))
      request = create_item_request(book)

      error = assert_raises(RuntimeError) { ItemRequestService.new(request).complete! }
      assert_equal "Can only complete an accepted request", error.message
      assert_equal ShareableItemStatus::AVAILABLE, book.reload.status
    end

    it "cancel! on a pending request leaves the item status unchanged" do
      book = setup_book_for_request(items(:one))
      request = create_item_request(book)

      ItemRequestService.new(request).cancel!

      assert_equal ItemRequest::CANCELLED_STATUS, request.reload.status
      assert_equal ShareableItemStatus::AVAILABLE, book.reload.status
    end
  end

  describe "transition table" do
    def accepted_request(book)
      request = create_item_request(book)
      ItemRequestService.new(request).accept!
      request
    end

    it "accepts an in-review request" do
      book = setup_book_for_request(items(:one))
      request = create_item_request(book, status: ItemRequest::IN_REVIEW_STATUS)

      ItemRequestService.new(request).accept!

      assert_equal ItemRequest::ACCEPTED_STATUS, request.reload.status
      assert_equal ShareableItemStatus::REQUESTED, book.reload.status
    end

    it "cancels an in-review request" do
      book = setup_book_for_request(items(:one))
      request = create_item_request(book, status: ItemRequest::IN_REVIEW_STATUS)

      ItemRequestService.new(request).cancel!

      assert_equal ItemRequest::CANCELLED_STATUS, request.reload.status
    end

    it "refuses to cancel a declined request" do
      book = setup_book_for_request(items(:one))
      request = create_item_request(book, status: ItemRequest::DECLINED_STATUS)

      error = assert_raises(RuntimeError) { ItemRequestService.new(request).cancel! }
      assert_equal "Cannot cancel a declined request", error.message
      assert_equal ItemRequest::DECLINED_STATUS, request.reload.status
    end

    it "refuses to accept a second request while one is accepted" do
      book = setup_book_for_request(items(:one))
      other = create_item_request(book, requester: create_other_requester)
      accepted_request(book)

      error = assert_raises(RuntimeError) { ItemRequestService.new(other.reload).accept! }
      assert_equal "Another request for this item has already been accepted", error.message
      assert_equal ItemRequest::IN_REVIEW_STATUS, other.reload.status
    end

    it "frees the item when the owner declines the accepted request, so another can be accepted" do
      book = setup_book_for_request(items(:one))
      other = create_item_request(book, requester: create_other_requester, status: ItemRequest::IN_REVIEW_STATUS)
      request = accepted_request(book)

      ItemRequestService.new(request).decline!

      assert_equal ItemRequest::DECLINED_STATUS, request.reload.status
      assert_equal ShareableItemStatus::AVAILABLE, book.reload.status

      ItemRequestService.new(other).accept!
      assert_equal ItemRequest::ACCEPTED_STATUS, other.reload.status
      assert_equal ShareableItemStatus::REQUESTED, book.reload.status
    end

    it "refuses to accept or decline a completed request and keeps the item donated" do
      book = setup_book_for_request(items(:one))
      request = accepted_request(book)
      ItemRequestService.new(request).complete!

      accept_error = assert_raises(RuntimeError) { ItemRequestService.new(request).accept! }
      assert_equal "Cannot accept a completed request", accept_error.message
      decline_error = assert_raises(RuntimeError) { ItemRequestService.new(request).decline! }
      assert_equal "Cannot decline a completed request", decline_error.message

      assert_equal ItemRequest::COMPLETED_STATUS, request.reload.status
      assert_equal ShareableItemStatus::DONATED, book.reload.status
    end

    it "refuses to accept or complete a declined request" do
      book = setup_book_for_request(items(:one))
      request = create_item_request(book, status: ItemRequest::DECLINED_STATUS)

      assert_equal "Cannot accept a declined request",
        assert_raises(RuntimeError) { ItemRequestService.new(request).accept! }.message
      assert_equal "Cannot complete a declined request",
        assert_raises(RuntimeError) { ItemRequestService.new(request).complete! }.message
      assert_equal ShareableItemStatus::AVAILABLE, book.reload.status
    end

    it "refuses to uncancel when the item has been donated" do
      book = setup_book_for_request(items(:one))
      cancelled = create_item_request(book, requester: create_other_requester, status: ItemRequest::CANCELLED_STATUS)
      winner = accepted_request(book)
      ItemRequestService.new(winner).complete!

      error = assert_raises(RuntimeError) { ItemRequestService.new(cancelled).uncancel! }
      assert_equal "This item has already been donated", error.message
      assert_equal ItemRequest::CANCELLED_STATUS, cancelled.reload.status
    end

    it "refuses to uncancel while another request is accepted" do
      book = setup_book_for_request(items(:one))
      cancelled = create_item_request(book, requester: create_other_requester, status: ItemRequest::CANCELLED_STATUS)
      accepted_request(book)

      error = assert_raises(RuntimeError) { ItemRequestService.new(cancelled).uncancel! }
      assert_equal "Another request for this item has already been accepted", error.message
    end

    it "refuses a move when the request was changed elsewhere since it was loaded" do
      book = setup_book_for_request(items(:one))
      request = create_item_request(book)
      stale = ItemRequest.find(request.id)
      ItemRequestService.new(request).decline!

      error = assert_raises(RuntimeError) { ItemRequestService.new(stale).accept! }
      assert_match "just updated by someone else", error.message
      assert_equal ItemRequest::DECLINED_STATUS, request.reload.status
      assert_equal ShareableItemStatus::AVAILABLE, book.reload.status
    end

    it "gives an uncancelled wish the donor as owner so it shows in their received requests" do
      wish = Book.create!(
        user_id: nil,
        title: "Uncancel Wish",
        author: "Author",
        summary: "Summary text long enough for validations on the book model here.",
        published_year: 2020,
        genre: "Fiction",
        status: ShareableItemStatus::WISHLIST
      )
      waiting = ItemRequest.create!(item: wish, requester: @requester, status: ItemRequest::PENDING_STATUS)
      cancelled = ItemRequest.create!(item: wish, requester: create_other_requester, status: ItemRequest::CANCELLED_STATUS)
      assert ItemService.new(wish).fulfill_wishlist_item(@owner, { condition: "good" })
      assert_nil cancelled.reload.owner_id

      ItemRequestService.new(cancelled).uncancel!

      cancelled.reload
      assert_equal ItemRequest::PENDING_STATUS, cancelled.status
      assert_equal @owner.id, cancelled.owner_id
      assert_includes ItemRequestService.new.requests_for_user(@owner, "received"), cancelled
      assert_includes ItemRequestService.new.requests_for_user(@owner, "received"), waiting
    end

    it "locks the owner's status buttons on finished requests" do
      book = setup_book_for_request(items(:one))
      [ ItemRequest::DECLINED_STATUS, ItemRequest::COMPLETED_STATUS, ItemRequest::CANCELLED_STATUS ].each do |status|
        assert_equal false, create_item_request(book, requester: create_other_requester, status: status).can_update_status?
      end
      assert create_item_request(book).can_update_status?
    end

    it "exposes can_cancel and can_uncancel in request_json" do
      book = setup_book_for_request(items(:one))
      json_for = ->(status) { service.request_json(create_item_request(book, requester: create_other_requester, status: status)) }

      pending = json_for.call(ItemRequest::PENDING_STATUS)
      assert_equal [ true, false ], [ pending[:can_cancel], pending[:can_uncancel] ]
      declined = json_for.call(ItemRequest::DECLINED_STATUS)
      assert_equal [ false, false ], [ declined[:can_cancel], declined[:can_uncancel] ]
      cancelled = json_for.call(ItemRequest::CANCELLED_STATUS)
      assert_equal [ false, true ], [ cancelled[:can_cancel], cancelled[:can_uncancel] ]

      book.update!(status: ShareableItemStatus::DONATED)
      assert_equal false, service.request_json(ItemRequest.find(cancelled[:id]))[:can_uncancel]
    end
  end

  describe "close-out on complete!" do
    def build_wish(requesters)
      wish = Book.create!(
        user_id: nil, title: "Shared Wish", author: "Wish Author", isbn: "9780000000001", genre: "Fiction",
        published_year: 2020, summary: "Summary text long enough for validations on the book model here.",
        status: ShareableItemStatus::WISHLIST
      )
      GroupItemAvailability.create!(item: wish, community_group: @other_group, sub_group: sub_groups(:one))
      requests = requesters.each_with_index.map do |(user, status), i|
        ItemRequest.create!(item: wish, requester: user,
          status: status, created_at: (requesters.size - i).hours.ago)
      end
      [ wish, requests ]
    end

    it "declines the other open requests on a regular item" do
      book = setup_book_for_request(items(:one))
      winner = create_item_request(book)
      in_review = create_item_request(book, requester: create_other_requester)
      declined = create_item_request(book, requester: create_other_requester, status: ItemRequest::DECLINED_STATUS)
      cancelled = create_item_request(book, requester: create_other_requester, status: ItemRequest::CANCELLED_STATUS)
      ItemRequestService.new(winner).accept!

      assert_no_difference -> { Item.count } do
        ItemRequestService.new(winner.reload).complete!
      end

      assert_equal ItemRequest::DECLINED_STATUS, in_review.reload.status
      assert_equal ItemRequest::DECLINED_STATUS, declined.reload.status
      assert_equal ItemRequest::CANCELLED_STATUS, cancelled.reload.status
      assert_equal ShareableItemStatus::DONATED, book.reload.status
      assert_equal false, in_review.can_update_status?
      assert_equal [ false, false ], service.request_json(in_review).values_at(:can_cancel, :can_uncancel)
      error = assert_raises(RuntimeError) { ItemRequestService.new(in_review).cancel! }
      assert_equal "Cannot cancel a declined request", error.message
    end

    it "moves the other wishers to a new wish in the same groups" do
      b_user = create_other_requester
      c_user = create_other_requester
      d_user = create_other_requester
      wish, (a, b, c, d) = build_wish([
        [ @requester, ItemRequest::PENDING_STATUS ],
        [ b_user, ItemRequest::PENDING_STATUS ],
        [ c_user, ItemRequest::PENDING_STATUS ],
        [ d_user, ItemRequest::CANCELLED_STATUS ]
      ])
      wish.cover_image.attach(io: StringIO.new("cover"), filename: "cover.jpg", content_type: "image/jpeg")
      # The donor's form sends the wish's group; its sub-group must survive to the relisted wish.
      assert ItemService.new(wish).fulfill_wishlist_item(@owner, { condition: "good", community_group_ids: [ @other_group.id ] })

      ItemRequestService.new(a.reload).accept!
      ItemRequestService.new(a.reload).complete!

      wish.reload
      assert_equal ShareableItemStatus::DONATED, wish.status
      assert_equal [ a.id, d.id ].sort, wish.item_requests.pluck(:id).sort
      assert_equal ItemRequest::CANCELLED_STATUS, d.reload.status

      new_wish = b.reload.item
      assert_not_equal wish.id, new_wish.id
      assert_equal new_wish, c.reload.item
      assert new_wish.wishlist?
      assert_nil new_wish.user_id
      assert_equal [ "Book", "Shared Wish", "Wish Author", "9780000000001" ],
        [ new_wish.type, new_wish.title, new_wish.author, new_wish.isbn ]
      assert_equal wish.cover_image.blob, new_wish.cover_image.blob
      assert_equal [ [ @other_group.id, sub_groups(:one).id ] ],
        new_wish.group_item_availabilities.pluck(:community_group_id, :sub_group_id)
      [ b, c ].each do |request|
        assert_equal ItemRequest::PENDING_STATUS, request.status
        assert_nil request.owner_id
      end
      assert_equal [ b_user, c_user ], new_wish.requesters.to_a
      assert_equal b_user, new_wish.original_requester
    end

    it "creates no new wish when nobody else is still waiting" do
      wish, (a, _b) = build_wish([
        [ @requester, ItemRequest::PENDING_STATUS ],
        [ create_other_requester, ItemRequest::CANCELLED_STATUS ]
      ])
      assert ItemService.new(wish).fulfill_wishlist_item(@owner, { condition: "good" })
      ItemRequestService.new(a.reload).accept!

      assert_no_difference -> { Item.count } do
        ItemRequestService.new(a.reload).complete!
      end
      assert_equal ShareableItemStatus::DONATED, wish.reload.status
    end

    it "rolls back the whole handoff when relisting the wish fails" do
      wish, (a, b) = build_wish([
        [ @requester, ItemRequest::PENDING_STATUS ],
        [ create_other_requester, ItemRequest::PENDING_STATUS ]
      ])
      assert ItemService.new(wish).fulfill_wishlist_item(@owner, { condition: "good" })
      ItemRequestService.new(a.reload).accept!
      failing = Object.new
      failing.define_singleton_method(:relist_as_wish!) { raise ActiveRecord::RecordInvalid, Item.new }

      ItemService.stub(:new, failing) do
        assert_raises(ActiveRecord::RecordInvalid) { ItemRequestService.new(a.reload).complete! }
      end

      assert_equal ItemRequest::ACCEPTED_STATUS, a.reload.status
      assert_equal ShareableItemStatus::REQUESTED, wish.reload.status
      assert_equal wish.id, b.reload.item_id
      assert_equal ItemRequest::IN_REVIEW_STATUS, b.status
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
        status: ShareableItemStatus::AVAILABLE
      )
      setup_book_for_request(book2)

      request1 = ItemRequest.create!(
        item: book1,
        requester: @requester,
        owner: @owner,
        status: ItemRequest::PENDING_STATUS
      )
      request2 = ItemRequest.create!(
        item: book2,
        requester: @requester,
        owner: @owner,
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
        status: ShareableItemStatus::AVAILABLE
      )
      setup_book_for_request(book2)

      request1 = ItemRequest.create!(
        item: book1,
        requester: @requester,
        owner: @owner,
        status: ItemRequest::PENDING_STATUS
      )
      request2 = ItemRequest.create!(
        item: book2,
        requester: @requester,
        owner: @owner,
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
      item_request = ItemRequestService.new.start_request!(@requester, book, "Test message that is long enough")

      json = service.request_json(item_request)

      assert_equal item_request.id, json[:id]
      assert_equal item_request.status, json[:status]
      assert_equal "Pending", json[:status_display]
      assert_equal "Test message that is long enough", json[:message]
      assert_equal true, json[:message_thread_writable]
      assert_equal item_request.created_at, json[:created_at]
      assert_equal item_request.updated_at, json[:updated_at]
      assert json[:book].present?
      assert json[:can_update_status].present?
      assert_equal @requester.id, json[:requester][:id]
      assert_equal @requester.display_name, json[:requester][:name]
      assert_equal @requester.location, json[:requester][:location]
      assert_equal @requester.verified?, json[:requester][:verified]
    end

    it "reports whether the thread takes messages, from the request" do
      book = setup_book_for_request(items(:one))
      item_request = ItemRequestService.new.start_request!(@requester, book, "Test message that is long enough")

      item_request.stub(:message_thread_writable?, false) do
        assert_equal false, service.request_json(item_request)[:message_thread_writable]
      end
    end

    it "includes book JSON in request JSON" do
      book = setup_book_for_request(items(:one))
      item_request = ItemRequestService.new.start_request!(@requester, book, "Test message that is long enough")

      json = service.request_json(item_request)

      assert json[:book].is_a?(Hash)
      assert_equal book.id, json[:book][:id]
      assert_equal book.title, json[:book][:title]
    end
  end

  describe "#requests_json" do
    it "gives each request its own initial message, loading them all in one query" do
      book = setup_book_for_request(items(:one))
      first = ItemRequestService.new.start_request!(@requester, book, "First requester's message here")
      second = ItemRequestService.new.start_request!(create_other_requester, book, "Second requester's message")
      # A later PENDING event (a reopen) must not replace the initial message.
      first.messages.create!(user: @requester, request_transition_status: ItemRequest::PENDING_STATUS, content: "Reopening")
      requests = ItemRequest.where(id: [ first.id, second.id ]).order(:id).to_a

      message_queries = 0
      count = ->(*, payload) { message_queries += 1 if payload[:sql].include?('FROM "messages"') }
      json = ActiveRecord::Base.uncached do
        ActiveSupport::Notifications.subscribed(count, "sql.active_record") { service.requests_json(requests) }
      end

      assert_equal [ "First requester's message here", "Second requester's message" ], json.map { |row| row[:message] }
      assert_equal 1, message_queries
    end

    it "returns an empty list for no requests" do
      assert_equal [], service.requests_json([])
    end
  end

  # GS-9 Part A: every status change records one transition event in the request's thread.
  describe "transition events" do
    before do
      @book = setup_book_for_request(items(:one))
    end

    def create_group_member(name)
      user = User.create!(email_address: "#{name}_#{SecureRandom.hex(4)}@example.com", verified: true,
        password_digest: BCrypt::Password.create("password123!"))
      user.update_columns(first_name: name.capitalize, last_name: "Tester", zip_code: "12345")
      CommunityGroupMembership.create!(user: user, community_group: @other_group)
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
          title: "Evented Wish", author: "Author", published_year: 2020, community_group_id: @other_group.id,
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
        second = request_for(create_group_member("second"))

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
        other = request_for(create_group_member("other"))
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
        GroupItemAvailability.create!(item: wish, community_group: @other_group)
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
        second_user = create_group_member("second")
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

    describe "naming events" do
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

    it "returns 'Cancelled' for CANCELLED_STATUS" do
      assert_equal "Cancelled", service.display_status(ItemRequest::CANCELLED_STATUS)
    end

    it "returns 'Pending' for unknown status" do
      assert_equal "Pending", service.display_status(999)
    end
  end

  def remove_user_from_group(user, group)
    CommunityGroupMembership.where(user: user, community_group: group).delete_all
  end
end
