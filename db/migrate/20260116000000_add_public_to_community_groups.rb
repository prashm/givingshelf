class AddPublicToCommunityGroups < ActiveRecord::Migration[8.0]
  def change
    add_column :community_groups, :public, :boolean, null: false, default: false
    add_index :community_groups, :public
  end
end
