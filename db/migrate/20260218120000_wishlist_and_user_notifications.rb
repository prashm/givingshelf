# frozen_string_literal: true

class WishlistAndUserNotifications < ActiveRecord::Migration[8.1]
  def up
    change_column_null :items, :user_id, true
    change_column_null :item_requests, :owner_id, true

    create_table :user_notifications do |t|
      t.references :user, null: false, foreign_key: true
      t.references :notifiable, polymorphic: true, null: false
      t.string :kind, null: false
      t.datetime :sent_at
      t.timestamps
    end
    add_index :user_notifications, [ :user_id, :notifiable_type, :notifiable_id, :kind ], unique: true, name: "index_user_notifications_dedup"
  end

  def down
    drop_table :user_notifications
    change_column_null :item_requests, :owner_id, false
    change_column_null :items, :user_id, false
  end
end
