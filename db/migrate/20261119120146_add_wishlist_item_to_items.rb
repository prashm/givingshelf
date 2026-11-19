class AddWishlistItemToItems < ActiveRecord::Migration[8.1]
  def up
    # True for an item that started as a wish, and it stays true after a donor fulfills it.
    # The status column can't tell us this once the wish becomes AVAILABLE.
    add_column :items, :wishlist_item, :boolean, default: false, null: false
    # Open wishes. Wishes fulfilled before this column existed can't be told apart from regular items.
    execute "UPDATE items SET wishlist_item = TRUE WHERE status = 3"
  end

  def down
    remove_column :items, :wishlist_item
  end
end
