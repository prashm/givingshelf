# GS-12: an item deleted while it has requests is kept, hidden, so its requests and their threads
# survive. Items that never had a request are still destroyed.
class AddDeletedAtToItems < ActiveRecord::Migration[8.1]
  def change
    add_column :items, :deleted_at, :datetime
    add_index :items, :deleted_at
  end
end
