require "test_helper"
require "minitest/spec"

class ItemServiceTest < ActiveSupport::TestCase
  extend Minitest::Spec::DSL

  def setup
    @user = users(:one)
    @group_one = community_groups(:one)
    @group_two = community_groups(:two)
    @sub_group_one = sub_groups(:one)
    @sub_group_two = sub_groups(:two)
    @item = Book.create!(
      user: @user,
      type: Book.name,
      title: "Sync Target",
      author: "Test Author",
      condition: "good",
      summary: "Long enough summary for sync_group_item_availabilities tests.",
      genre: "Fiction",
      published_year: 2020,
      status: ShareableItemStatus::AVAILABLE
    )
    @service = ItemService.new(@item)
  end

  def availability_pairs
    @item.reload
    @item.group_item_availabilities
      .pluck(:community_group_id, :sub_group_id)
      .sort_by { |(group_id, _sub_group_id)| group_id }
  end

  describe "#sync_group_item_availabilities!" do
    it "creates expected rows for hash input scope" do
      @service.send(:sync_group_item_availabilities!, @user, {
        @group_one.id => @sub_group_one.id,
        @group_two.id => nil
      })

      assert_equal [
        [ @group_one.id, @sub_group_one.id ],
        [ @group_two.id, nil ]
      ].sort_by { |(group_id, _)| group_id }, availability_pairs
    end

    it "normalizes string keys and blank subgroup values in hash input" do
      @service.send(:sync_group_item_availabilities!, @user, {
        @group_one.id.to_s => "",
        @group_two.id.to_s => nil
      })

      assert_equal [
        [ @group_one.id, nil ],
        [ @group_two.id, nil ]
      ].sort_by { |(group_id, _)| group_id }, availability_pairs
    end

    it "updates existing rows and removes rows not in desired scope" do
      GroupItemAvailability.create!(item: @item, community_group: @group_one, sub_group: @sub_group_one)
      GroupItemAvailability.create!(item: @item, community_group: @group_two, sub_group: nil)

      @service.send(:sync_group_item_availabilities!, @user, { @group_one.id => @sub_group_two.id })

      assert_equal [ [ @group_one.id, @sub_group_two.id ] ], availability_pairs
    end

    it "is a no-op when existing rows already match desired scope" do
      existing_one = GroupItemAvailability.create!(item: @item, community_group: @group_one, sub_group: @sub_group_one)
      existing_two = GroupItemAvailability.create!(item: @item, community_group: @group_two, sub_group: nil)
      existing_snapshot = @item.group_item_availabilities
        .order(:id)
        .pluck(:id, :community_group_id, :sub_group_id, :created_at, :updated_at)

      @service.send(:sync_group_item_availabilities!, @user, {
        @group_one.id => @sub_group_one.id,
        @group_two.id => nil
      })

      after_rows = @item.reload.group_item_availabilities.order(:id).pluck(:id, :community_group_id, :sub_group_id, :created_at, :updated_at)

      assert_equal existing_snapshot, after_rows
      assert_equal existing_one.updated_at, existing_one.reload.updated_at
      assert_equal existing_two.updated_at, existing_two.reload.updated_at
    end

    it "raises when scope input is not a hash" do
      err = assert_raises(RuntimeError) do
        @service.send(:sync_group_item_availabilities!, @user, [ @group_one.id ])
      end

      assert_match "community_group_ids must be a hash", err.message
    end
  end

  describe "#fulfill_wishlist_item" do
    def create_wishlist_with_request
      wishlist_book = Book.create!(
        user_id: nil,
        title: "Wishlist Fulfill Book",
        author: "Author",
        summary: "Summary text long enough for validations on the book model here.",
        published_year: 2020,
        genre: "Fiction",
        status: ShareableItemStatus::WISHLIST
      )
      request = ItemRequest.create!(
        item: wishlist_book,
        requester: users(:two),
        owner: nil,
        message: "I would love this book if anyone in the community has a copy.",
        status: ItemRequest::PENDING_STATUS
      )
      [ wishlist_book, request ]
    end

    it "assigns the donor, matches pending requests and notifies requesters" do
      wishlist_book, request = create_wishlist_with_request
      service = ItemService.new(wishlist_book)

      assert_difference -> { UserNotification.where(kind: UserNotification::KIND_WISHLIST_AVAILABLE).count }, 1 do
        assert service.fulfill_wishlist_item(@user, { condition: "good" })
      end

      wishlist_book.reload
      assert_equal @user.id, wishlist_book.user_id
      assert_equal ShareableItemStatus::AVAILABLE, wishlist_book.status
      request.reload
      assert_equal ItemRequest::IN_REVIEW_STATUS, request.status
      assert_equal @user.id, request.owner_id
    end

    it "rolls back the item update and sends no notifications when matching a request fails" do
      wishlist_book, request = create_wishlist_with_request
      service = ItemService.new(wishlist_book)
      failing_request_service = Object.new
      failing_request_service.define_singleton_method(:match_wishlist_donor!) { |_donor| raise ActiveRecord::RecordNotSaved, "match failed" }

      ItemRequestService.stub(:new, failing_request_service) do
        assert_no_difference -> { UserNotification.count } do
          assert_equal false, service.fulfill_wishlist_item(@user, { condition: "good" })
        end
      end

      assert_includes service.errors, "match failed"
      wishlist_book.reload
      assert_nil wishlist_book.user_id
      assert_equal ShareableItemStatus::WISHLIST, wishlist_book.status
      assert_equal ItemRequest::PENDING_STATUS, request.reload.status
    end

    it "refuses to fulfill a wish nobody is waiting for any more" do
      wishlist_book, request = create_wishlist_with_request
      request.update!(status: ItemRequest::CANCELLED_STATUS)
      service = ItemService.new(wishlist_book)

      assert_no_difference -> { UserNotification.count } do
        assert_equal false, service.fulfill_wishlist_item(@user, { condition: "good" })
      end

      assert_includes service.errors, "No one is waiting for this item anymore"
      wishlist_book.reload
      assert_nil wishlist_book.user_id
      assert_equal ShareableItemStatus::WISHLIST, wishlist_book.status
    end

    it "refuses a donor who cancelled their own request on the wish" do
      wishlist_book, _request = create_wishlist_with_request
      ItemRequest.create!(
        item: wishlist_book,
        requester: @user,
        owner: nil,
        message: "I wished for this too but then cancelled it.",
        status: ItemRequest::CANCELLED_STATUS
      )
      service = ItemService.new(wishlist_book)

      assert_equal false, service.fulfill_wishlist_item(@user, { condition: "good" })

      assert_includes service.errors, "You cannot fulfill your own wishlist request"
      assert_nil wishlist_book.reload.user_id
    end

    it "keeps the item marked as a wishlist item after a donor fulfills it" do
      wishlist_book, _request = create_wishlist_with_request
      assert wishlist_book.wishlist_item?

      assert ItemService.new(wishlist_book).fulfill_wishlist_item(@user, { condition: "good" })

      wishlist_book.reload
      assert_equal ShareableItemStatus::AVAILABLE, wishlist_book.status
      assert wishlist_book.wishlist_item?
      assert_not @item.wishlist_item?
    end

    it "returns false and changes nothing when the item update fails" do
      wishlist_book, request = create_wishlist_with_request
      service = ItemService.new(wishlist_book)

      assert_equal false, service.fulfill_wishlist_item(@user, { condition: "not-a-condition" })

      assert service.errors.any?
      wishlist_book.reload
      assert_nil wishlist_book.user_id
      assert_equal ShareableItemStatus::WISHLIST, wishlist_book.status
      assert_equal ItemRequest::PENDING_STATUS, request.reload.status
    end
  end

  describe "#relist_as_wish!" do
    def fulfilled_wish
      wish = Book.create!(
        user_id: nil, title: "Relist Me", author: "Wish Author", isbn: "9780000000002", genre: "Fiction",
        published_year: 2019, summary: "Summary text long enough for validations on the book model here.",
        status: ShareableItemStatus::WISHLIST
      )
      GroupItemAvailability.create!(item: wish, community_group: @group_one, sub_group: @sub_group_one)
      GroupItemAvailability.create!(item: wish, community_group: @group_two)
      request = ItemRequest.create!(item: wish, requester: users(:two), message: "I would love this book please")
      wish.cover_image.attach(io: StringIO.new("cover"), filename: "cover.jpg", content_type: "image/jpeg")
      wish.update!(user: @user, status: ShareableItemStatus::DONATED, condition: "good")
      [ wish, request ]
    end

    it "creates an ownerless wish with the same details, cover and groups" do
      wish, _request = fulfilled_wish

      new_wish = ItemService.new(wish).relist_as_wish!

      assert new_wish.persisted?
      assert_not_equal wish.id, new_wish.id
      assert new_wish.wishlist?
      assert new_wish.wishlist_item?
      assert_nil new_wish.user_id
      assert_nil new_wish.condition
      assert_equal wish.attributes.slice(*ItemService::WISH_COPY_ATTRIBUTES),
        new_wish.attributes.slice(*ItemService::WISH_COPY_ATTRIBUTES)
      assert_equal wish.cover_image.blob, new_wish.cover_image.blob
      assert_equal [ [ @group_one.id, @sub_group_one.id ], [ @group_two.id, nil ] ].sort_by { |g, _| g },
        new_wish.group_item_availabilities.pluck(:community_group_id, :sub_group_id).sort_by { |g, _| g }
    end

    it "leaves the original item, its groups and its requests untouched" do
      wish, request = fulfilled_wish

      ItemService.new(wish).relist_as_wish!

      wish.reload
      assert_equal ShareableItemStatus::DONATED, wish.status
      assert_equal @user, wish.user
      assert_equal 2, wish.group_item_availabilities.count
      assert_equal wish.id, request.reload.item_id
      assert wish.cover_image.attached?
    end

    it "creates the wish with no groups or cover when the item has none" do
      wish, _request = fulfilled_wish
      wish.group_item_availabilities.delete_all
      wish.cover_image.purge

      new_wish = ItemService.new(wish.reload).relist_as_wish!

      assert new_wish.wishlist?
      assert_empty new_wish.group_item_availabilities
      assert_not new_wish.cover_image.attached?
    end

    it "refuses an item that did not start as a wish" do
      error = assert_raises(RuntimeError) { ItemService.new(@item).relist_as_wish! }

      assert_equal "Item did not start as a wish", error.message
      assert_no_difference -> { Item.count } do
        assert_raises(RuntimeError) { ItemService.new(@item).relist_as_wish! }
      end
    end
  end
end
