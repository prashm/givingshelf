require "test_helper"
require "minitest/spec"

class BookServiceTest < ActiveSupport::TestCase
  extend Minitest::Spec::DSL

  def setup
    @user = users(:one)
    @zip_group = CommunityGroup.find_or_create_zipcode_group!

    @other_group = community_groups(:one)
    CommunityGroupMembership.find_or_create_by!(user: @user, community_group: @other_group) do |m|
      m.admin = false
      m.auto_joined = false
    end
    CommunityGroupMembership.find_or_create_by!(user: @user, community_group: @zip_group) do |m|
      m.admin = false
      m.auto_joined = true
    end
  end

  def teardown
    CommunityGroupMembership.delete_all
    GroupItemAvailability.delete_all
  end

  private

  def setup_book_for_request_test(book, groups: [], status: BookStatus::AVAILABLE)
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

  def remove_user_from_group(user, group)
    CommunityGroupMembership.where(user: user, community_group: group).delete_all
  end

  def create_item_request(book, requester, status: ItemRequest::PENDING_STATUS)
    ItemRequest.create!(
      item: book,
      requester: requester,
      owner: book.user,
      message: "Test message that is long enough",
      status: status
    )
  end

  describe "#create_item" do
    it "returns nil and sets error when user profile is incomplete" do
      service = BookService.new
      @user.stub(:profile_complete?, false) do
        book = service.create_item(@user, {
          type: Book.name,
          title: "A Title",
          author: "An Author",
          condition: "good",
          summary: "This is a test book summary that is long enough.",
          published_year: 2020
        })

        assert_nil book
        assert_includes service.errors.join(" "), "User profile is incomplete"
      end
    end

    it "creates group book availabilities for selected groups" do
      service = BookService.new
      book = service.create_item(@user, {
        type: Book.name,
        title: "A Title",
        author: "An Author",
        condition: "good",
        summary: "This is a test book summary that is long enough.",
        published_year: 2020,
        community_group_ids: [ @zip_group.id, @other_group.id ]
      })

      assert book, service.errors.to_sentence
      assert GroupItemAvailability.exists?(item: book, community_group: @zip_group)
      assert GroupItemAvailability.exists?(item: book, community_group: @other_group)
    end

    it "defaults to ZIP group when community_group_ids not provided" do
      service = BookService.new
      book = service.create_item(@user, {
        type: Book.name,
        title: "A Title 2",
        author: "An Author 2",
        condition: "good",
        summary: "This is a test book summary that is long enough.",
        published_year: 2020
      })

      assert book, service.errors.to_sentence
      assert GroupItemAvailability.exists?(item: book, community_group: @zip_group)
    end

    it "ignores selecting a group the user is not a member of" do
      outsider_group = community_groups(:two)
      CommunityGroupMembership.where(user: @user, community_group: outsider_group).delete_all

      service = BookService.new
      book = service.create_item(@user, {
        type: Book.name,
        title: "A Title 3",
        author: "An Author 3",
        condition: "good",
        summary: "This is a test book summary that is long enough.",
        published_year: 2020,
        community_group_ids: [ outsider_group.id ]
      })

      assert book, service.errors.to_sentence
      assert_not GroupItemAvailability.exists?(item: book, community_group: outsider_group)
    end
  end

  describe "#update_item" do
    it "adds and removes group book availabilities" do
      book = items(:one)
      GroupItemAvailability.where(item: book).delete_all
      GroupItemAvailability.create!(item: book, community_group: @zip_group)

      service = BookService.new(book)
      ok = service.update_item(@user, { community_group_ids: [ @other_group.id ] })
      assert ok, service.errors.to_sentence

      assert_not GroupItemAvailability.exists?(item: book, community_group: @zip_group)
      assert GroupItemAvailability.exists?(item: book, community_group: @other_group)
    end

    it "does not change group availability when community_group_ids is not provided" do
      book = items(:one)
      GroupItemAvailability.where(item: book).delete_all
      GroupItemAvailability.create!(item: book, community_group: @zip_group)

      service = BookService.new(book)
      ok = service.update_item(@user, { title: "Updated Without Groups" })
      assert ok, service.errors.to_sentence

      assert GroupItemAvailability.exists?(item: book, community_group: @zip_group)
      assert_equal 1, GroupItemAvailability.where(item: book).count
    end

    it "ignores selecting a group the user is not a member of" do
      outsider_group = community_groups(:two)
      CommunityGroupMembership.where(user: @user, community_group: outsider_group).delete_all

      book = items(:one)
      service = BookService.new(book)
      ok = service.update_item(@user, { community_group_ids: [ outsider_group.id ] })
      assert ok, service.errors.to_sentence
      assert_not GroupItemAvailability.exists?(item: book, community_group: outsider_group)
    end
  end

  describe "#remove_item" do
    it "returns false when non-owner tries to delete" do
      book = items(:one)
      service = BookService.new(book)
      ok = service.remove_item(users(:two))
      assert_not ok
      assert_includes service.errors.join(" "), "Not authorized"
    end
  end

  describe "#track_item_view" do
    it "increments view_count for non-owner but not for owner" do
      book = items(:one)
      book.update!(view_count: 0)
      service = BookService.new(book)

      count = service.track_item_view(users(:two))
      assert_equal 1, count

      count2 = service.track_item_view(users(:one))
      assert_equal 1, count2
    end
  end

  describe "#search_items" do
    def ensure_zip_availability_for(*items)
      items.flatten.each do |i|
        GroupItemAvailability.find_or_create_by!(item: i, community_group: @zip_group)
      end
    end

    it "filters by group availability when community_group_id is present" do
      group = @other_group
      # Make only items(:one) available in this group
      GroupItemAvailability.where(item: items(:one), community_group: group).delete_all
      GroupItemAvailability.where(item: items(:two), community_group: group).delete_all
      GroupItemAvailability.create!(item: items(:one), community_group: group)

      service = BookService.new
      result = service.search_items(query_string: "", zip_code: nil, community_group_id: group.id)
      ids = result.pluck(:id)
      assert_includes ids, items(:one).id
      assert_not_includes ids, items(:two).id
    end

    it "filters by sub_group_id within a community group" do
      group = community_groups(:one)
      sg1 = sub_groups(:one)
      sg2 = sub_groups(:two)

      # Ensure both books are available in the group
      GroupItemAvailability.find_or_create_by!(item: items(:one), community_group: group)
      GroupItemAvailability.find_or_create_by!(item: items(:two), community_group: group)

      # Set owners' membership subgroups for the group
      CommunityGroupMembership.find_by!(user: users(:one), community_group: group).update!(sub_group_id: sg1.id)
      CommunityGroupMembership.find_by!(user: users(:two), community_group: group).update!(sub_group_id: sg2.id)

      service = BookService.new
      result = service.search_items(query_string: "", zip_code: nil, community_group_id: group.id, sub_group_id: sg1.id)
      ids = result.pluck(:id)
      assert_includes ids, items(:one).id
      assert_not_includes ids, items(:two).id
    end

    it "filters by query_string across title and author" do
      ensure_zip_availability_for(items(:one), items(:two))

      service = BookService.new
      result = service.search_items(query_string: "gatsby", zip_code: nil, community_group_id: nil)
      ids = result.pluck(:id)
      assert_includes ids, items(:one).id
      assert_not_includes ids, items(:two).id

      result2 = service.search_items(query_string: "harper", zip_code: nil, community_group_id: nil)
      ids2 = result2.pluck(:id)
      assert_includes ids2, items(:two).id
      assert_not_includes ids2, items(:one).id
    end

    it "filters by zip_code (exact match) when radius is not provided" do
      ensure_zip_availability_for(items(:one), items(:two))

      service = BookService.new
      result = service.search_items(query_string: "", zip_code: users(:one).zip_code, radius: nil, community_group_id: nil)
      ids = result.pluck(:id)
      assert_includes ids, items(:one).id
      assert_not_includes ids, items(:two).id
    end

    it "filters by radius when geocoding succeeds" do
      ensure_zip_availability_for(items(:one), items(:two))

      # Put one user at the search point and another far away.
      users(:one).update!(latitude: 0.0, longitude: 0.0)
      users(:two).update!(latitude: 40.0, longitude: 40.0)

      fake_avs = Object.new
      def fake_avs.geocode_zip_code(_zip) = { latitude: 0.0, longitude: 0.0 }
      def fake_avs.errors = []

      AddressVerificationService.stub(:new, fake_avs) do
        service = BookService.new
        result = service.search_items(query_string: "", zip_code: "12345", radius: "10", community_group_id: nil)
        ids = result.pluck(:id)
        assert_includes ids, items(:one).id
        assert_not_includes ids, items(:two).id
      end
    end

    it "falls back to exact zip_code match when geocoding fails" do
      ensure_zip_availability_for(items(:one), items(:two))

      fake_avs = Object.new
      def fake_avs.geocode_zip_code(_zip) = nil
      def fake_avs.errors = [ "no results" ]

      AddressVerificationService.stub(:new, fake_avs) do
        service = BookService.new
        result = service.search_items(query_string: "", zip_code: users(:one).zip_code, radius: "10", community_group_id: nil)
        ids = result.pluck(:id)
        assert_includes ids, items(:one).id
        assert_not_includes ids, items(:two).id
      end
    end

    it "defaults to ZIP group availability when community_group_id is not provided" do
      # Ensure only items(:one) is available in zip group
      GroupItemAvailability.where(item: items(:one), community_group: @zip_group).delete_all
      GroupItemAvailability.where(item: items(:two), community_group: @zip_group).delete_all
      GroupItemAvailability.create!(item: items(:one), community_group: @zip_group)

      service = BookService.new
      result = service.search_items(query_string: "", zip_code: nil, community_group_id: nil)
      ids = result.pluck(:id)
      assert_includes ids, items(:one).id
      assert_not_includes ids, items(:two).id
    end
  end

  describe "#item_can_be_requested_by?" do
    it "returns false when user is nil" do
      book = items(:one)
      service = BookService.new(book)
      result = service.item_can_be_requested_by?(nil)
      assert_not result
      assert_nil service.item_cannot_be_requested_by_reason
    end

    it "returns false when book is not available" do
      book = setup_book_for_request_test(items(:one), status: BookStatus::DONATED)
      requester = users(:two)
      service = BookService.new(book)
      result = service.item_can_be_requested_by?(requester)
      assert_not result
      assert_nil service.item_cannot_be_requested_by_reason
    end

    it "returns false when user is the owner" do
      book = items(:one)
      service = BookService.new(book)
      result = service.item_can_be_requested_by?(book.user)
      assert_not result
      assert_nil service.item_cannot_be_requested_by_reason
    end

    it "returns false with reason when user has pending request" do
      book = setup_book_for_request_test(items(:one), groups: [ @other_group ])
      requester = users(:two)
      add_user_to_group(requester, @other_group)
      create_item_request(book, requester, status: ItemRequest::PENDING_STATUS)

      service = BookService.new(book)
      result = service.item_can_be_requested_by?(requester)
      assert_not result
      assert_equal "You already requested this item", service.item_cannot_be_requested_by_reason
    end

    it "returns false with reason when user has accepted request" do
      book = setup_book_for_request_test(items(:one), groups: [ @other_group ])
      requester = users(:two)
      add_user_to_group(requester, @other_group)
      create_item_request(book, requester, status: ItemRequest::ACCEPTED_STATUS)

      service = BookService.new(book)
      result = service.item_can_be_requested_by?(requester)
      assert_not result
      assert_equal "You already requested this item", service.item_cannot_be_requested_by_reason
    end

    it "returns false with reason when book has no groups" do
      book = setup_book_for_request_test(items(:one), groups: [])
      requester = users(:two)

      service = BookService.new(book)
      result = service.item_can_be_requested_by?(requester)
      assert_not result
      assert_equal "This item is not shared in any groups", service.item_cannot_be_requested_by_reason
    end

    it "returns false with reason when user is not in any of the book's groups" do
      book = setup_book_for_request_test(items(:one), groups: [ @other_group ])
      requester = users(:two)
      remove_user_from_group(requester, @other_group)

      service = BookService.new(book)
      result = service.item_can_be_requested_by?(requester)
      assert_not result
      assert_equal "You are not a member of any groups this item is shared in", service.item_cannot_be_requested_by_reason
    end

    it "returns true when user can request the book" do
      book = setup_book_for_request_test(items(:one), groups: [ @other_group ])
      requester = users(:two)
      add_user_to_group(requester, @other_group)

      service = BookService.new(book)
      result = service.item_can_be_requested_by?(requester)
      assert result
      assert_nil service.item_cannot_be_requested_by_reason
    end

    it "returns true when book is in zipcode group and user is in zipcode group" do
      book = setup_book_for_request_test(items(:one), groups: [ @zip_group ])
      requester = users(:two)
      add_user_to_group(requester, @zip_group, auto_joined: true)

      service = BookService.new(book)
      result = service.item_can_be_requested_by?(requester)
      assert result
      assert_nil service.item_cannot_be_requested_by_reason
    end

    it "prioritizes pending request reason over group membership reason" do
      book = setup_book_for_request_test(items(:one), groups: [ @other_group ])
      requester = users(:two)
      add_user_to_group(requester, @other_group)
      create_item_request(book, requester, status: ItemRequest::PENDING_STATUS)
      remove_user_from_group(requester, @other_group)

      service = BookService.new(book)
      result = service.item_can_be_requested_by?(requester)
      assert_not result
      assert_equal "You already requested this item", service.item_cannot_be_requested_by_reason
    end

    it "allows a community member to request a wishlist book when not the original requester" do
      book = Book.create!(
        user_id: nil,
        type: Book.name,
        title: "Shared Wish",
        author: "Author",
        summary: "Long enough summary for a wishlist item request eligibility test here.",
        published_year: 2020,
        genre: "Fiction",
        status: ShareableItemStatus::WISHLIST
      )
      GroupItemAvailability.create!(item: book, community_group: @other_group)
      ItemRequest.create!(
        item: book,
        requester: @user,
        owner: nil,
        message: "I would love this book if anyone in the community has a copy.",
        status: ItemRequest::PENDING_STATUS
      )
      other = users(:two)
      add_user_to_group(other, @other_group)

      service = BookService.new(book)
      assert service.item_can_be_requested_by?(other)
      assert_nil service.item_cannot_be_requested_by_reason
    end
  end

  describe "#book_json" do
    def setup_book_groups(book, groups)
      GroupItemAvailability.where(item: book).delete_all
      groups.each { |group| GroupItemAvailability.create!(item: book, community_group: group) }
    end

    it "includes community_group_ids from availabilities" do
      book = items(:one)
      setup_book_groups(book, [ @zip_group, @other_group ])

      service = BookService.new(book)
      json = service.item_detail_map(book, @user)
      assert_equal [ @zip_group.id, @other_group.id ].sort, Array(json[:community_group_ids]).sort
    end

    it "displays zipcode group name as 'ZIP_CODE Community' in community_group_names" do
      book = items(:one)
      book.user.update!(zip_code: "12345")
      setup_book_groups(book, [ @zip_group ])

      service = BookService.new(book)
      json = service.item_detail_map(book, @user)

      assert_includes json[:community_group_names], "12345 Community"
      assert_equal 1, json[:community_group_names].length
    end

    it "displays regular group names as-is in community_group_names" do
      book = items(:one)
      setup_book_groups(book, [ @other_group ])

      service = BookService.new(book)
      json = service.item_detail_map(book, @user)

      assert_includes json[:community_group_names], @other_group.name
      assert_equal 1, json[:community_group_names].length
    end

    it "displays both zipcode and regular group names correctly" do
      book = items(:one)
      book.user.update!(zip_code: "54321")
      setup_book_groups(book, [ @zip_group, @other_group ])

      service = BookService.new(book)
      json = service.item_detail_map(book, @user)

      assert_includes json[:community_group_names], "54321 Community"
      assert_includes json[:community_group_names], @other_group.name
      assert_equal 2, json[:community_group_names].length
    end

    it "includes can_request and cannot_request_reason when requester can request" do
      book = setup_book_for_request_test(items(:one), groups: [ @other_group ])
      requester = users(:two)
      add_user_to_group(requester, @other_group)

      service = BookService.new(book)
      json = service.item_detail_map(book, requester)

      assert json[:can_request]
      assert_nil json[:cannot_request_reason]
      assert_nil json[:user_request_id]
      assert_nil json[:user_request_dt]
    end

    it "includes can_request and cannot_request_reason when requester has pending request" do
      book = setup_book_for_request_test(items(:one), groups: [ @other_group ])
      requester = users(:two)
      add_user_to_group(requester, @other_group)
      request = create_item_request(book, requester, status: ItemRequest::PENDING_STATUS)

      service = BookService.new(book)
      json = service.item_detail_map(book, requester)

      assert_not json[:can_request]
      assert_equal "You already requested this item", json[:cannot_request_reason]
      assert_equal request.id, json[:user_request_id]
      assert_equal request.created_at, json[:user_request_dt]
    end

    it "includes can_request and cannot_request_reason when book has no groups" do
      book = setup_book_for_request_test(items(:one), groups: [])
      requester = users(:two)

      service = BookService.new(book)
      json = service.item_detail_map(book, requester)

      assert_not json[:can_request]
      assert_equal "This item is not shared in any groups", json[:cannot_request_reason]
    end

    it "includes can_request and cannot_request_reason when requester is not in book's groups" do
      book = setup_book_for_request_test(items(:one), groups: [ @other_group ])
      requester = users(:two)
      remove_user_from_group(requester, @other_group)

      service = BookService.new(book)
      json = service.item_detail_map(book, requester)

      assert_not json[:can_request]
      assert_equal "You are not a member of any groups this item is shared in", json[:cannot_request_reason]
    end

    it "includes can_request and cannot_request_reason when requester is nil" do
      book = setup_book_for_request_test(items(:one), groups: [ @other_group ])

      service = BookService.new(book)
      json = service.item_detail_map(book, nil)

      assert_not json[:can_request]
      assert_nil json[:cannot_request_reason]
    end
  end

  describe "#community_group_stats" do
    it "returns group-scoped shared/donated/requested counts" do
      group = community_groups(:one)

      # Ensure both books are available in the group
      GroupItemAvailability.find_or_create_by!(item: items(:one), community_group: group)
      GroupItemAvailability.find_or_create_by!(item: items(:two), community_group: group)

      # Mark one book as donated
      items(:two).update!(status: BookStatus::DONATED)

      service = BookService.new
      stats = service.community_group_stats(community_group_id: group.id)

      assert_equal 1, stats[:items_shared]
      assert_equal 1, stats[:items_donated]
      assert_equal 2, stats[:items_requested]
      assert_equal 2, stats[:members]
    end

    it "filters stats by sub_group_id (owner membership subgroup)" do
      group = community_groups(:one)
      sg1 = sub_groups(:one)
      sg2 = sub_groups(:two)

      # Ensure both books are available in the group
      GroupItemAvailability.find_or_create_by!(item: items(:one), community_group: group)
      GroupItemAvailability.find_or_create_by!(item: items(:two), community_group: group)

      # Assign membership subgroups for owners
      CommunityGroupMembership.find_by!(user: users(:one), community_group: group).update!(sub_group_id: sg1.id)
      CommunityGroupMembership.find_by!(user: users(:two), community_group: group).update!(sub_group_id: sg2.id)

      # Mark user2's book as donated
      items(:two).update!(status: BookStatus::DONATED)

      service = BookService.new
      stats_sg1 = service.community_group_stats(community_group_id: group.id, sub_group_id: sg1.id)
      stats_sg2 = service.community_group_stats(community_group_id: group.id, sub_group_id: sg2.id)

      assert_equal 1, stats_sg1[:items_shared]
      assert_equal 0, stats_sg1[:items_donated]
      assert_equal 1, stats_sg1[:items_requested]

      assert_equal 0, stats_sg2[:items_shared]
      assert_equal 1, stats_sg2[:items_donated]
      assert_equal 1, stats_sg2[:items_requested]
      assert_equal 1, stats_sg2[:members]
    end

    it "returns zero members for a sub group with no memberships" do
      group = community_groups(:one)
      sg1 = sub_groups(:one)
      sg2 = sub_groups(:two)

      # Put all members into sg1, leaving sg2 with zero members
      CommunityGroupMembership.where(community_group: group).update_all(sub_group_id: sg1.id)

      # Ensure books exist in the group (owned by sg1 members)
      GroupItemAvailability.find_or_create_by!(item: items(:one), community_group: group)
      GroupItemAvailability.find_or_create_by!(item: items(:two), community_group: group)

      service = BookService.new
      stats = service.community_group_stats(community_group_id: group.id, sub_group_id: sg2.id)

      assert_equal 0, stats[:members]
      assert_equal 0, stats[:items_shared]
      assert_equal 0, stats[:items_donated]
      assert_equal 0, stats[:items_requested]
    end
  end

  describe "#create_wishlist_item" do
    it "creates wishlist book, pending item request, and group availability" do
      service = BookService.new
      book = service.create_wishlist_item(@user, {
        title: "New Wish",
        author: "Author McAuthor",
        summary: "A summary that is more than long enough to validate successfully.",
        published_year: 2020,
        community_group_id: @other_group.id
      })
      assert book, service.errors.to_sentence
      assert book.wishlist?
      assert_nil book.user_id
      assert_equal [ @other_group.id ], book.group_item_availabilities.pluck(:community_group_id)
      ir = book.item_requests.find_by(requester: @user)
      assert ir
      assert_equal ItemRequest::PENDING_STATUS, ir.status
      assert_nil ir.owner_id
      assert_equal BookService::DEFAULT_WISHLIST_MESSAGE, ir.message
      gia = book.group_item_availabilities.find_by(community_group_id: @other_group.id)
      assert gia
      assert_nil gia.sub_group_id
    end

    it "stores subgroup scope on group item availability" do
      user_membership = CommunityGroupMembership.find_by!(user: @user, community_group: @other_group)
      user_membership.update!(sub_group_id: sub_groups(:one).id)
      service = BookService.new
      book = service.create_wishlist_item(@user, {
        title: "Scoped Wish",
        author: "Author",
        summary: "A summary that is more than long enough to validate successfully.",
        published_year: 2020,
        community_group_id: @other_group.id,
        sub_group_id: sub_groups(:one).id
      })
      assert book, service.errors.to_sentence
      gia = book.group_item_availabilities.find_by(community_group_id: @other_group.id)
      assert_equal sub_groups(:one).id, gia.sub_group_id
    end

    it "returns nil when sub_group does not match requester membership" do
      user_membership = CommunityGroupMembership.find_by!(user: @user, community_group: @other_group)
      user_membership.update!(sub_group_id: sub_groups(:one).id)
      service = BookService.new
      book = service.create_wishlist_item(@user, {
        title: "Scoped Wish",
        author: "Author",
        summary: "A summary that is more than long enough to validate successfully.",
        published_year: 2020,
        community_group_id: @other_group.id,
        sub_group_id: sub_groups(:two).id
      })
      assert_nil book
      assert_includes service.errors.join(" "), "Invalid subgroup selection"
    end

    it "returns nil when profile is incomplete" do
      service = BookService.new
      @user.stub(:profile_complete?, false) do
        book = service.create_wishlist_item(@user, {
          title: "T",
          author: "A",
          summary: "A long enough default summary to avoid length errors here.",
          published_year: 2020
        })
        assert_nil book
        assert_includes service.errors.join(" ").downcase, "incomplete"
      end
    end
  end
end
