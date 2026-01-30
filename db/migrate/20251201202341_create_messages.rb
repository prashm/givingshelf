class CreateMessages < ActiveRecord::Migration[8.0]
  def change
    create_table :messages do |t|
      t.references :item_request, null: false, foreign_key: true
      t.references :user, null: false, foreign_key: true
      t.text :content
      t.datetime :read_at

      t.timestamps
    end

    add_index :messages, [ :item_request_id, :created_at ]
  end
end
