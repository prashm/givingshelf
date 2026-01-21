class CreateGroupBookAvailabilities < ActiveRecord::Migration[8.0]
  def up
    create_table :group_book_availabilities do |t|
      t.references :book, null: false, foreign_key: true
      t.references :community_group, null: false, foreign_key: true
      t.timestamps
    end

    add_index :group_book_availabilities, [ :book_id, :community_group_id ],
              unique: true,
              name: "index_gba_on_book_id_and_community_group_id"
  end

  def down
    drop_table :group_book_availabilities
  end
end
