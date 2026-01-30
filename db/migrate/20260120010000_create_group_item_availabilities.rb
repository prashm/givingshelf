# Creates group_item_availabilities (references items for STI).
# Original migration created :group_book_availabilities; we create :group_item_availabilities for a fresh STI schema.
class CreateGroupItemAvailabilities < ActiveRecord::Migration[8.0]
  def change
    create_table :group_item_availabilities do |t|
      t.references :item, null: false, foreign_key: true
      t.references :community_group, null: false, foreign_key: true
      t.timestamps
    end

    add_index :group_item_availabilities, [ :item_id, :community_group_id ],
              unique: true,
              name: "index_gia_on_item_id_and_community_group_id"
  end
end
