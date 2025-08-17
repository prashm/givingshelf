class CreateBookRequests < ActiveRecord::Migration[8.0]
  def change
    create_table :book_requests do |t|
      t.references :requester, null: false, foreign_key: { to_table: :users }
      t.references :book, null: false, foreign_key: true
      t.string :status
      t.text :message

      t.timestamps
    end
  end
end
