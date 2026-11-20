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
      request = ItemRequest.create!(item: wish, requester: users(:two))
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

  describe "locked wish identity" do
    def open_wish
      wish = Book.create!(
        user_id: nil, title: "Locked Wish", author: "Wish Author", genre: "Fiction", published_year: 2021,
        summary: "Summary text long enough for validations on the book model here.",
        status: ShareableItemStatus::WISHLIST
      )
      GroupItemAvailability.create!(item: wish, community_group: @group_one, sub_group: @sub_group_one)
      ItemRequest.create!(item: wish, requester: users(:two))
      wish
    end

    def group_pairs(item)
      item.reload.group_item_availabilities.pluck(:community_group_id, :sub_group_id)
    end

    it "keeps the wish's groups and sub-group when the donor sends the same groups" do
      wish = open_wish

      assert ItemService.new(wish).fulfill_wishlist_item(@user, { condition: "good", community_group_ids: [ @group_one.id ] })

      assert_equal ShareableItemStatus::AVAILABLE, wish.reload.status
      assert_equal [ [ @group_one.id, @sub_group_one.id ] ], group_pairs(wish)
    end

    it "refuses a fulfillment that changes the wish's groups and leaves the wish open" do
      wish = open_wish
      service = ItemService.new(wish)

      assert_not service.fulfill_wishlist_item(@user, { condition: "good", community_group_ids: [ @group_one.id, @group_two.id ] })

      assert_includes service.errors, "You're trying to edit a restricted field for this wishlist item"
      assert_equal ShareableItemStatus::WISHLIST, wish.reload.status
      assert_nil wish.user_id
      assert_equal [ [ @group_one.id, @sub_group_one.id ] ], group_pairs(wish)
    end

    it "refuses an owner edit that changes the title or author of a fulfilled wish" do
      wish = open_wish
      assert ItemService.new(wish).fulfill_wishlist_item(@user, { condition: "good" })

      [ { title: "Something Else" }, { author: "Someone Else" } ].each do |change|
        service = ItemService.new(wish.reload)
        assert_not service.update_item(@user, change.dup), "#{change.keys.first} should be locked"
        assert_includes service.errors, "You're trying to edit a restricted field for this wishlist item"
      end
      assert_equal [ "Locked Wish", "Wish Author" ], [ wish.reload.title, wish.author ]
    end

    it "accepts an owner edit that sends the locked fields unchanged and keeps the sub-group" do
      wish = open_wish
      assert ItemService.new(wish).fulfill_wishlist_item(@user, { condition: "good" })

      assert ItemService.new(wish.reload).update_item(@user, {
        title: "Locked Wish", author: "Wish Author", community_group_ids: [ @group_one.id ],
        summary: "A new summary that is long enough for the validations here."
      })

      assert_equal "A new summary that is long enough for the validations here.", wish.reload.summary
      assert_equal [ [ @group_one.id, @sub_group_one.id ] ], group_pairs(wish)
    end

    it "still lets a regular item change its title and groups" do
      GroupItemAvailability.create!(item: @item, community_group: @group_one)

      assert @service.update_item(@user, { title: "Renamed", community_group_ids: [ @group_two.id ] })

      assert_equal "Renamed", @item.reload.title
      assert_equal [ [ @group_two.id, nil ] ], group_pairs(@item)
    end
  end

  describe "item JSON" do
    COMMON_LIST_KEYS = %i[id type title summary condition status status_display wishlist_item cover_image_url created_at].freeze
    COMMON_DETAIL_KEYS = %i[
      id type title condition summary status status_display wishlist_item cover_image_url user_images_urls
      view_count personal_note pickup_method pickup_address community_group_ids community_group_names owner
      request_count created_at updated_at can_request
    ].freeze

    it "builds the same list and detail keys for books and toys as before the refactor" do
      book = items(:one)
      toy = items(:toy_one)

      assert_equal (COMMON_LIST_KEYS + %i[author genre published_year]).sort, ItemService.new.item_map(book).keys.sort
      assert_equal (COMMON_LIST_KEYS + %i[brand age_range age_range_display min_age max_age]).sort, ItemService.new.item_map(toy).keys.sort
      assert_equal (COMMON_DETAIL_KEYS + %i[author genre published_year isbn]).sort,
        ItemService.new.item_detail_map(book).keys.sort
      assert_equal (COMMON_DETAIL_KEYS + %i[brand age_range age_range_display min_age max_age]).sort,
        ItemService.new.item_detail_map(toy).keys.sort
    end

    it "gives the same result from the typed service and the plain one" do
      book = items(:one)
      assert_equal BookService.new(book).item_detail_map(book, users(:two)), ItemService.new.item_detail_map(book, users(:two))
    end

    it "names an open wish's ZIP group after its active requesters' ZIP codes" do
      zip_group = CommunityGroup.find_or_create_zipcode_group!
      wish = Book.create!(
        user_id: nil, title: "Zip Wish", author: "Author", genre: "Fiction", published_year: 2020,
        summary: "Summary text long enough for validations on the book model here.",
        status: ShareableItemStatus::WISHLIST
      )
      GroupItemAvailability.create!(item: wish, community_group: zip_group)
      cancelled_user = User.create!(email_address: "zip_#{SecureRandom.hex(4)}@example.com", verified: true,
        password_digest: BCrypt::Password.create("password123!"))
      cancelled_user.update_columns(zip_code: "99999")
      ItemRequest.create!(item: wish, requester: users(:two))
      ItemRequest.create!(item: wish, requester: users(:one))
      ItemRequest.create!(item: wish, requester: cancelled_user,
        status: ItemRequest::CANCELLED_STATUS)

      assert_equal [ "12345, 54321 Community" ], ItemService.new.item_detail_map(wish)[:community_group_names]

      ItemRequest.where(item: wish).delete_all
      assert_equal [ "ZIP Code Community" ], ItemService.new.item_detail_map(wish.reload)[:community_group_names]
    end

    it "names any other item's ZIP group after its owner's ZIP code" do
      zip_group = CommunityGroup.find_or_create_zipcode_group!
      GroupItemAvailability.create!(item: @item, community_group: zip_group)

      assert_equal [ "#{@user.zip_code} Community" ], ItemService.new.item_detail_map(@item)[:community_group_names]
    end
  end

  # Unit tests for the matching query behind joining a wish (GS-13). The create flow that uses it
  # is tested in book_service_test.rb ("joining an existing wish").
  describe "#find_matching_wish" do
    # An ownerless wish shared in group (and sub_group), with users(:two) waiting on it.
    def wish(title: "Matched Wish", author: "Jane Writer", isbn: nil, group: @group_one, sub_group: nil, waiting: users(:two))
      book = Book.create!(
        user_id: nil, title: title, author: author, isbn: isbn, genre: "Fiction", published_year: 2020,
        summary: "Summary text long enough for validations on the book model here.",
        status: ShareableItemStatus::WISHLIST
      )
      GroupItemAvailability.create!(item: book, community_group: group, sub_group: sub_group)
      ItemRequest.create!(item: book, requester: waiting) if waiting
      book
    end

    def find(attrs = {}, group: @group_one, sub_group: nil, requester: @user, service: BookService.new)
      service.find_matching_wish(requester, { title: "Matched Wish", author: "Jane Writer" }.merge(attrs), group.id, sub_group&.id)
    end

    def create_user(name, zip_code: "12345")
      user = User.create!(email_address: "#{name}_#{SecureRandom.hex(4)}@example.com", verified: true,
        password_digest: BCrypt::Password.create("password123!"))
      user.update_columns(first_name: name.capitalize, last_name: "Tester", zip_code: zip_code)
      user
    end

    describe "identity" do
      it "matches the title and author whatever the case and spacing" do
        match = wish
        assert_equal match, find({ title: "  matched   WISH ", author: "jane writer" })
      end

      it "needs the same author too" do
        wish
        assert_nil find({ author: "Someone Else" })
      end

      it "matches a book with the same ISBN-13 under another title, from ISBN-10 input" do
        match = wish(title: "Matched Wish (Paperback)", isbn: "9780306406157")
        assert_equal match, find({ title: "Something else", isbn: "0-306-40615-2" })
      end

      it "matches a toy on its title and brand, and never a book" do
        toy = Toy.create!(user_id: nil, title: "Matched Wish", brand: "Lego", age_range: "5-7",
          summary: "A long enough summary for wishlist toy matching assertions here.",
          status: ShareableItemStatus::WISHLIST)
        GroupItemAvailability.create!(item: toy, community_group: @group_one)
        ItemRequest.create!(item: toy, requester: users(:two))

        assert_equal toy, find({ brand: "LEGO" }, service: ToyService.new)
        assert_nil find({ brand: "Mattel" }, service: ToyService.new)
        assert_nil find, "a book search doesn't return the toy"
      end

      it "returns the oldest match" do
        older = wish
        wish(waiting: create_user("later"))
        assert_equal older, find
      end
    end

    describe "candidates" do
      it "needs someone still waiting" do
        match = wish
        match.item_requests.update_all(status: ItemRequest::CANCELLED_STATUS)
        assert_nil find
        match.item_requests.update_all(status: ItemRequest::DECLINED_STATUS)
        assert_nil find
      end

      it "includes a fulfilled wish until it's donated" do
        match = wish
        donor = create_user("donor")
        match.update_columns(user_id: donor.id, status: ShareableItemStatus::AVAILABLE)
        assert_equal match, find
        match.update_columns(status: ShareableItemStatus::REQUESTED)
        match.item_requests.update_all(status: ItemRequest::ACCEPTED_STATUS)
        assert_equal match, find, "an accepted request still counts as waiting"
        match.update_columns(status: ShareableItemStatus::DONATED)
        assert_nil find
      end

      it "skips an item the requester is giving away themselves" do
        match = wish
        match.update_columns(user_id: @user.id, status: ShareableItemStatus::AVAILABLE)
        assert_nil find
      end

      it "skips an item that didn't start as a wish" do
        @item.update!(title: "Matched Wish", author: "Jane Writer")
        GroupItemAvailability.create!(item: @item, community_group: @group_one)
        ItemRequest.create!(item: @item, requester: users(:two))
        assert_nil find
      end
    end

    describe "location" do
      it "needs the same group" do
        wish(group: @group_two)
        assert_nil find
      end

      it "without a sub-group, matches only a wish with no sub-group" do
        wish(sub_group: @sub_group_one)
        assert_nil find
        match = wish(waiting: create_user("nosub"))
        assert_equal match, find
      end

      it "matches a wish in the requester's sub-group, but not another sub-group" do
        match = wish(sub_group: @sub_group_one)
        assert_equal match, find(sub_group: @sub_group_one)
        assert_nil find(sub_group: @sub_group_two)
      end

      it "matches a wish someone waiting on belongs to the requester's sub-group" do
        match = wish(sub_group: @sub_group_one)
        neighbour = create_user("neighbour")
        CommunityGroupMembership.create!(user: neighbour, community_group: @group_one, sub_group: @sub_group_two)
        ItemRequest.create!(item: match, requester: neighbour)
        assert_equal match, find(sub_group: @sub_group_two)

        match.item_requests.where(requester: neighbour).update_all(status: ItemRequest::CANCELLED_STATUS)
        assert_nil find(sub_group: @sub_group_two), "only people still waiting count"
      end

      it "in the ZIP Code Community, needs someone waiting with the requester's ZIP code" do
        zip_group = CommunityGroup.find_or_create_zipcode_group!
        match = wish(group: zip_group, waiting: create_user("near", zip_code: "94110"))

        assert_nil find(group: zip_group, requester: create_user("far", zip_code: "10001"))
        assert_equal match, find(group: zip_group, requester: create_user("close", zip_code: "94110"))
      end
    end
  end
end
