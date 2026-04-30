require "test_helper"
require "minitest/spec"

class ToyServiceTest < ActiveSupport::TestCase
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

  def setup_toy_for_request_test(toy, groups: [], status: ShareableItemStatus::AVAILABLE)
    ItemRequest.where(item: toy).destroy_all
    GroupItemAvailability.where(item: toy).delete_all
    groups.each { |group| GroupItemAvailability.create!(item: toy, community_group: group) }
    toy.update!(status: status)
    toy
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

  def create_item_request(toy, requester, status: ItemRequest::PENDING_STATUS)
    ItemRequest.create!(
      item: toy,
      requester: requester,
      owner: toy.user,
      message: "Test message that is long enough",
      status: status
    )
  end

  describe "#create_item" do
    it "returns nil and sets error when user profile is incomplete" do
      service = ToyService.new
      @user.stub(:profile_complete?, false) do
        toy = service.create_item(@user, {
          type: Toy.name,
          title: "A Toy",
          brand: "Hasbro",
          condition: "good",
          summary: "This is a test toy summary that is long enough."
        })

        assert_nil toy
        assert_includes service.errors.join(" "), "User profile is incomplete"
      end
    end

    it "creates group toy availabilities for selected groups" do
      service = ToyService.new
      toy = service.create_item(@user, {
        type: Toy.name,
        title: "A Toy",
        brand: "Hasbro",
        condition: "good",
        summary: "This is a test toy summary that is long enough.",
        community_group_ids: [ @zip_group.id, @other_group.id ]
      })

      assert toy, service.errors.to_sentence
      assert GroupItemAvailability.exists?(item: toy, community_group: @zip_group)
      assert GroupItemAvailability.exists?(item: toy, community_group: @other_group)
    end

    it "defaults to ZIP group when community_group_ids not provided" do
      service = ToyService.new
      toy = service.create_item(@user, {
        type: Toy.name,
        title: "A Toy 2",
        brand: "Mattel",
        condition: "good",
        summary: "This is a test toy summary that is long enough."
      })

      assert toy, service.errors.to_sentence
      assert GroupItemAvailability.exists?(item: toy, community_group: @zip_group)
    end

    it "ignores selecting a group the user is not a member of" do
      outsider_group = community_groups(:two)
      CommunityGroupMembership.where(user: @user, community_group: outsider_group).delete_all

      service = ToyService.new
      toy = service.create_item(@user, {
        type: Toy.name,
        title: "A Toy 3",
        brand: "Fisher-Price",
        condition: "good",
        summary: "This is a test toy summary that is long enough.",
        community_group_ids: [ outsider_group.id ]
      })

      assert toy, service.errors.to_sentence
      assert_not GroupItemAvailability.exists?(item: toy, community_group: outsider_group)
    end
  end

  describe "#update_item" do
    it "adds and removes group toy availabilities" do
      toy = items(:toy_one)
      GroupItemAvailability.where(item: toy).delete_all
      GroupItemAvailability.create!(item: toy, community_group: @zip_group)

      service = ToyService.new(toy)
      ok = service.update_item(@user, { community_group_ids: [ @other_group.id ] })
      assert ok, service.errors.to_sentence

      assert_not GroupItemAvailability.exists?(item: toy, community_group: @zip_group)
      assert GroupItemAvailability.exists?(item: toy, community_group: @other_group)
    end

    it "does not change group availability when community_group_ids is not provided" do
      toy = items(:toy_one)
      GroupItemAvailability.where(item: toy).delete_all
      GroupItemAvailability.create!(item: toy, community_group: @zip_group)

      service = ToyService.new(toy)
      ok = service.update_item(@user, { title: "Updated Without Groups" })
      assert ok, service.errors.to_sentence

      assert GroupItemAvailability.exists?(item: toy, community_group: @zip_group)
      assert_equal 1, GroupItemAvailability.where(item: toy).count
    end

    it "ignores selecting a group the user is not a member of" do
      outsider_group = community_groups(:two)
      CommunityGroupMembership.where(user: @user, community_group: outsider_group).delete_all

      toy = items(:toy_one)
      service = ToyService.new(toy)
      ok = service.update_item(@user, { community_group_ids: [ outsider_group.id ] })
      assert ok, service.errors.to_sentence
      assert_not GroupItemAvailability.exists?(item: toy, community_group: outsider_group)
    end
  end

  describe "#remove_item" do
    it "returns false when non-owner tries to delete" do
      toy = items(:toy_one)
      service = ToyService.new(toy)
      ok = service.remove_item(users(:two))
      assert_not ok
      assert_includes service.errors.join(" "), "Not authorized"
    end
  end

  describe "#track_item_view" do
    it "increments view_count for non-owner but not for owner" do
      toy = items(:toy_one)
      toy.update!(view_count: 0)
      service = ToyService.new(toy)

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
      GroupItemAvailability.where(item: items(:toy_one), community_group: group).delete_all
      GroupItemAvailability.where(item: items(:toy_two), community_group: group).delete_all
      GroupItemAvailability.create!(item: items(:toy_one), community_group: group)

      service = ToyService.new
      result = service.search_items(query_string: "", zip_code: nil, community_group_id: group.id)
      ids = result.pluck(:id)
      assert_includes ids, items(:toy_one).id
      assert_not_includes ids, items(:toy_two).id
    end

    it "filters by sub_group_id within a community group" do
      group = community_groups(:one)
      sg1 = sub_groups(:one)
      sg2 = sub_groups(:two)

      GroupItemAvailability.find_or_create_by!(item: items(:toy_one), community_group: group)
      GroupItemAvailability.find_or_create_by!(item: items(:toy_two), community_group: group)

      CommunityGroupMembership.find_by!(user: users(:one), community_group: group).update!(sub_group_id: sg1.id)
      CommunityGroupMembership.find_by!(user: users(:two), community_group: group).update!(sub_group_id: sg2.id)

      service = ToyService.new
      result = service.search_items(query_string: "", zip_code: nil, community_group_id: group.id, sub_group_id: sg1.id)
      ids = result.pluck(:id)
      assert_includes ids, items(:toy_one).id
      assert_not_includes ids, items(:toy_two).id
    end

    it "filters by query_string by title" do
      ensure_zip_availability_for(items(:toy_one), items(:toy_two))

      service = ToyService.new
      result = service.search_items(query_string: "Building", zip_code: nil, community_group_id: nil)
      ids = result.pluck(:id)
      assert_includes ids, items(:toy_one).id
      assert_not_includes ids, items(:toy_two).id

      result2 = service.search_items(query_string: "Farm", zip_code: nil, community_group_id: nil)
      ids2 = result2.pluck(:id)
      assert_includes ids2, items(:toy_two).id
      assert_not_includes ids2, items(:toy_one).id
    end

    it "filters by query_string across title and brand" do
      ensure_zip_availability_for(items(:toy_one), items(:toy_two))

      service = ToyService.new

      # Search by brand
      result = service.search_items(query_string: "Lego", zip_code: nil, community_group_id: nil)
      ids = result.pluck(:id)
      assert_includes ids, items(:toy_one).id
      assert_not_includes ids, items(:toy_two).id

      result2 = service.search_items(query_string: "Fisher", zip_code: nil, community_group_id: nil)
      ids2 = result2.pluck(:id)
      assert_includes ids2, items(:toy_two).id
      assert_not_includes ids2, items(:toy_one).id
    end

    it "filters by zip_code (exact match) when radius is not provided" do
      ensure_zip_availability_for(items(:toy_one), items(:toy_two))

      service = ToyService.new
      result = service.search_items(query_string: "", zip_code: users(:one).zip_code, radius: nil, community_group_id: nil)
      ids = result.pluck(:id)
      assert_includes ids, items(:toy_one).id
      assert_not_includes ids, items(:toy_two).id
    end

    it "filters by radius when geocoding succeeds" do
      ensure_zip_availability_for(items(:toy_one), items(:toy_two))

      users(:one).update!(latitude: 0.0, longitude: 0.0)
      users(:two).update!(latitude: 40.0, longitude: 40.0)

      fake_avs = Object.new
      def fake_avs.geocode_zip_code(_zip) = { latitude: 0.0, longitude: 0.0 }
      def fake_avs.errors = []

      AddressVerificationService.stub(:new, fake_avs) do
        service = ToyService.new
        result = service.search_items(query_string: "", zip_code: "12345", radius: "10", community_group_id: nil)
        ids = result.pluck(:id)
        assert_includes ids, items(:toy_one).id
        assert_not_includes ids, items(:toy_two).id
      end
    end

    it "falls back to exact zip_code match when geocoding fails" do
      ensure_zip_availability_for(items(:toy_one), items(:toy_two))

      fake_avs = Object.new
      def fake_avs.geocode_zip_code(_zip) = nil
      def fake_avs.errors = [ "no results" ]

      AddressVerificationService.stub(:new, fake_avs) do
        service = ToyService.new
        result = service.search_items(query_string: "", zip_code: users(:one).zip_code, radius: "10", community_group_id: nil)
        ids = result.pluck(:id)
        assert_includes ids, items(:toy_one).id
        assert_not_includes ids, items(:toy_two).id
      end
    end

    it "defaults to ZIP group availability when community_group_id is not provided" do
      GroupItemAvailability.where(item: items(:toy_one), community_group: @zip_group).delete_all
      GroupItemAvailability.where(item: items(:toy_two), community_group: @zip_group).delete_all
      GroupItemAvailability.create!(item: items(:toy_one), community_group: @zip_group)

      service = ToyService.new
      result = service.search_items(query_string: "", zip_code: nil, community_group_id: nil)
      ids = result.pluck(:id)
      assert_includes ids, items(:toy_one).id
      assert_not_includes ids, items(:toy_two).id
    end
  end

  describe "#item_can_be_requested_by?" do
    it "returns false when user is nil" do
      toy = items(:toy_one)
      service = ToyService.new(toy)
      result = service.item_can_be_requested_by?(nil)
      assert_not result
      assert_nil service.item_cannot_be_requested_by_reason
    end

    it "returns false when toy is not available" do
      toy = setup_toy_for_request_test(items(:toy_one), status: ShareableItemStatus::DONATED)
      requester = users(:two)
      service = ToyService.new(toy)
      result = service.item_can_be_requested_by?(requester)
      assert_not result
      assert_nil service.item_cannot_be_requested_by_reason
    end

    it "returns false when user is the owner" do
      toy = items(:toy_one)
      service = ToyService.new(toy)
      result = service.item_can_be_requested_by?(toy.user)
      assert_not result
      assert_nil service.item_cannot_be_requested_by_reason
    end

    it "returns false with reason when user has pending request" do
      toy = setup_toy_for_request_test(items(:toy_one), groups: [ @other_group ])
      requester = users(:two)
      add_user_to_group(requester, @other_group)
      create_item_request(toy, requester, status: ItemRequest::PENDING_STATUS)

      service = ToyService.new(toy)
      result = service.item_can_be_requested_by?(requester)
      assert_not result
      assert_equal "You already requested this item", service.item_cannot_be_requested_by_reason
    end

    it "returns false with reason when user has accepted request" do
      toy = setup_toy_for_request_test(items(:toy_one), groups: [ @other_group ])
      requester = users(:two)
      add_user_to_group(requester, @other_group)
      create_item_request(toy, requester, status: ItemRequest::ACCEPTED_STATUS)

      service = ToyService.new(toy)
      result = service.item_can_be_requested_by?(requester)
      assert_not result
      assert_equal "You already requested this item", service.item_cannot_be_requested_by_reason
    end

    it "returns false with reason when toy has no groups" do
      toy = setup_toy_for_request_test(items(:toy_one), groups: [])
      requester = users(:two)

      service = ToyService.new(toy)
      result = service.item_can_be_requested_by?(requester)
      assert_not result
      assert_equal "This item is not shared in any groups", service.item_cannot_be_requested_by_reason
    end

    it "returns false with reason when user is not in any of the toy's groups" do
      toy = setup_toy_for_request_test(items(:toy_one), groups: [ @other_group ])
      requester = users(:two)
      remove_user_from_group(requester, @other_group)

      service = ToyService.new(toy)
      result = service.item_can_be_requested_by?(requester)
      assert_not result
      assert_equal "You are not a member of any groups this item is shared in", service.item_cannot_be_requested_by_reason
    end

    it "returns true when user can request the toy" do
      toy = setup_toy_for_request_test(items(:toy_one), groups: [ @other_group ])
      requester = users(:two)
      add_user_to_group(requester, @other_group)

      service = ToyService.new(toy)
      result = service.item_can_be_requested_by?(requester)
      assert result
      assert_nil service.item_cannot_be_requested_by_reason
    end

    it "returns true when toy is in zipcode group and user is in zipcode group" do
      toy = setup_toy_for_request_test(items(:toy_one), groups: [ @zip_group ])
      requester = users(:two)
      add_user_to_group(requester, @zip_group, auto_joined: true)

      service = ToyService.new(toy)
      result = service.item_can_be_requested_by?(requester)
      assert result
      assert_nil service.item_cannot_be_requested_by_reason
    end

    it "prioritizes pending request reason over group membership reason" do
      toy = setup_toy_for_request_test(items(:toy_one), groups: [ @other_group ])
      requester = users(:two)
      add_user_to_group(requester, @other_group)
      create_item_request(toy, requester, status: ItemRequest::PENDING_STATUS)
      remove_user_from_group(requester, @other_group)

      service = ToyService.new(toy)
      result = service.item_can_be_requested_by?(requester)
      assert_not result
      assert_equal "You already requested this item", service.item_cannot_be_requested_by_reason
    end
  end

  describe "#item_detail_map" do
    def setup_toy_groups(toy, groups)
      GroupItemAvailability.where(item: toy).delete_all
      groups.each { |group| GroupItemAvailability.create!(item: toy, community_group: group) }
    end

    it "includes community_group_ids from availabilities" do
      toy = items(:toy_one)
      setup_toy_groups(toy, [ @zip_group, @other_group ])

      service = ToyService.new(toy)
      json = service.item_detail_map(toy, @user)
      assert_equal [ @zip_group.id, @other_group.id ].sort, Array(json[:community_group_ids]).sort
    end

    it "displays zipcode group name as 'ZIP_CODE Community' in community_group_names" do
      toy = items(:toy_one)
      toy.user.update!(zip_code: "12345")
      setup_toy_groups(toy, [ @zip_group ])

      service = ToyService.new(toy)
      json = service.item_detail_map(toy, @user)

      assert_includes json[:community_group_names], "12345 Community"
      assert_equal 1, json[:community_group_names].length
    end

    it "displays regular group names as-is in community_group_names" do
      toy = items(:toy_one)
      setup_toy_groups(toy, [ @other_group ])

      service = ToyService.new(toy)
      json = service.item_detail_map(toy, @user)

      assert_includes json[:community_group_names], @other_group.name
      assert_equal 1, json[:community_group_names].length
    end

    it "displays both zipcode and regular group names correctly" do
      toy = items(:toy_one)
      toy.user.update!(zip_code: "54321")
      setup_toy_groups(toy, [ @zip_group, @other_group ])

      service = ToyService.new(toy)
      json = service.item_detail_map(toy, @user)

      assert_includes json[:community_group_names], "54321 Community"
      assert_includes json[:community_group_names], @other_group.name
      assert_equal 2, json[:community_group_names].length
    end

    it "includes can_request and cannot_request_reason when requester can request" do
      toy = setup_toy_for_request_test(items(:toy_one), groups: [ @other_group ])
      requester = users(:two)
      add_user_to_group(requester, @other_group)

      service = ToyService.new(toy)
      json = service.item_detail_map(toy, requester)

      assert json[:can_request]
      assert_nil json[:cannot_request_reason]
      assert_nil json[:user_request_id]
      assert_nil json[:user_request_dt]
    end

    it "includes can_request and cannot_request_reason when requester has pending request" do
      toy = setup_toy_for_request_test(items(:toy_one), groups: [ @other_group ])
      requester = users(:two)
      add_user_to_group(requester, @other_group)
      request = create_item_request(toy, requester, status: ItemRequest::PENDING_STATUS)

      service = ToyService.new(toy)
      json = service.item_detail_map(toy, requester)

      assert_not json[:can_request]
      assert_equal "You already requested this item", json[:cannot_request_reason]
      assert_equal request.id, json[:user_request_id]
      assert_equal request.created_at, json[:user_request_dt]
    end

    it "includes can_request and cannot_request_reason when toy has no groups" do
      toy = setup_toy_for_request_test(items(:toy_one), groups: [])
      requester = users(:two)

      service = ToyService.new(toy)
      json = service.item_detail_map(toy, requester)

      assert_not json[:can_request]
      assert_equal "This item is not shared in any groups", json[:cannot_request_reason]
    end

    it "includes can_request and cannot_request_reason when requester is not in toy's groups" do
      toy = setup_toy_for_request_test(items(:toy_one), groups: [ @other_group ])
      requester = users(:two)
      remove_user_from_group(requester, @other_group)

      service = ToyService.new(toy)
      json = service.item_detail_map(toy, requester)

      assert_not json[:can_request]
      assert_equal "You are not a member of any groups this item is shared in", json[:cannot_request_reason]
    end

    it "includes can_request and cannot_request_reason when requester is nil" do
      toy = setup_toy_for_request_test(items(:toy_one), groups: [ @other_group ])

      service = ToyService.new(toy)
      json = service.item_detail_map(toy, nil)

      assert_not json[:can_request]
      assert_nil json[:cannot_request_reason]
    end
  end

  describe "#community_group_stats" do
    it "returns group-scoped shared/donated/requested counts" do
      group = community_groups(:one)

      GroupItemAvailability.find_or_create_by!(item: items(:toy_one), community_group: group)
      GroupItemAvailability.find_or_create_by!(item: items(:toy_two), community_group: group)

      items(:toy_two).update!(status: ShareableItemStatus::DONATED)

      service = ToyService.new
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

      GroupItemAvailability.find_or_create_by!(item: items(:toy_one), community_group: group)
      GroupItemAvailability.find_or_create_by!(item: items(:toy_two), community_group: group)

      CommunityGroupMembership.find_by!(user: users(:one), community_group: group).update!(sub_group_id: sg1.id)
      CommunityGroupMembership.find_by!(user: users(:two), community_group: group).update!(sub_group_id: sg2.id)

      items(:toy_two).update!(status: ShareableItemStatus::DONATED)

      service = ToyService.new
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

      CommunityGroupMembership.where(community_group: group).update_all(sub_group_id: sg1.id)

      GroupItemAvailability.find_or_create_by!(item: items(:toy_one), community_group: group)
      GroupItemAvailability.find_or_create_by!(item: items(:toy_two), community_group: group)

      service = ToyService.new
      stats = service.community_group_stats(community_group_id: group.id, sub_group_id: sg2.id)

      assert_equal 0, stats[:members]
      assert_equal 0, stats[:items_shared]
      assert_equal 0, stats[:items_donated]
      assert_equal 0, stats[:items_requested]
    end
  end
end
