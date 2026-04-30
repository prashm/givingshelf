class AddSubGroupToGroupItemAvailabilities < ActiveRecord::Migration[8.1]
  def change
    add_reference :group_item_availabilities, :sub_group, foreign_key: true
    add_index :group_item_availabilities, [ :community_group_id, :sub_group_id ], name: "index_gia_on_group_and_sub_group"
  end
end
