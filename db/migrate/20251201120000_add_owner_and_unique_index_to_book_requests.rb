class AddOwnerAndUniqueIndexToBookRequests < ActiveRecord::Migration[8.0]
  def change
    add_reference :book_requests, :owner, null: false, foreign_key: { to_table: :users }

    add_index :book_requests,
              [:book_id, :requester_id],
              unique: true,
              name: "index_book_requests_on_book_id_and_requester_id"
  end
end


