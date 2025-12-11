class AddFraudPreventionToUserSessions < ActiveRecord::Migration[8.0]
  def change
    add_column :user_sessions, :device_fingerprint, :string
    add_column :user_sessions, :suspicious_activity, :boolean, default: false, null: false

    add_index :user_sessions, :device_fingerprint
    add_index :user_sessions, :suspicious_activity
  end
end
