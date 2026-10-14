class DropActiveRecordSessions < ActiveRecord::Migration[8.0]
  # Leftover from 20251103032950; the activerecord-session_store gem uses the `sessions` table.
  def change
    drop_table :active_record_sessions, id: false do |t|
      t.string :id, limit: 128, primary_key: true
      t.text :data
      t.timestamps
      t.index :updated_at
    end
  end
end
