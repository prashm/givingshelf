# Creates item_requests table (references items for STI).
# Original migration created :book_requests; we create :item_requests for a fresh STI schema.
class CreateItemRequests < ActiveRecord::Migration[8.0]
  def change
    create_table :item_requests do |t|
      t.references :item, null: false, foreign_key: true
      t.references :requester, null: false, foreign_key: { to_table: :users }
      t.references :owner, null: false, foreign_key: { to_table: :users }
      t.integer :status, default: 0, null: false
      t.text :message

      t.timestamps
    end

    add_index :item_requests, :status
    add_index :item_requests,
              [ :item_id, :requester_id ],
              unique: true,
              name: "index_item_requests_on_item_id_and_requester_id"
  end
end
