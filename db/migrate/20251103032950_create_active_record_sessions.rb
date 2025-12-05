class CreateActiveRecordSessions < ActiveRecord::Migration[8.0]
  def change
    create_table :active_record_sessions, id: false do |t|
      t.string :id, limit: 128, primary_key: true
      t.text :data
      t.timestamps
    end

    add_index :active_record_sessions, :updated_at
  end
end
