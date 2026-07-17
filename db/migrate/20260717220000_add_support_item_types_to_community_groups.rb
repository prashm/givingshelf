class AddSupportItemTypesToCommunityGroups < ActiveRecord::Migration[8.0]
  def change
    add_column :community_groups, :support_item_types, :string, limit: 10
    add_index :community_groups, :support_item_types
  end
end
