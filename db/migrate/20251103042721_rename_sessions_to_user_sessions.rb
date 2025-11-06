class RenameSessionsToUserSessions < ActiveRecord::Migration[8.0]
  def up
    rename_table :sessions, :user_sessions
    rename_index :user_sessions, 'index_sessions_on_user_id', 'index_user_sessions_on_user_id'
  end

  def down
    rename_table :user_sessions, :sessions
    rename_index :sessions, 'index_user_sessions_on_user_id', 'index_sessions_on_user_id'
  end
end
