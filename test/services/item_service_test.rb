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
end
