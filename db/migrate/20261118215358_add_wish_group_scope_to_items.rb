class AddWishGroupScopeToItems < ActiveRecord::Migration[8.1]
  def change
    # Set when a donor fulfills a wish: the wish's { community_group_id => sub_group_id } availabilities
    # before the donor's groups replaced them. Nil for items that never were a wish.
    add_column :items, :wish_group_scope, :jsonb
  end
end
