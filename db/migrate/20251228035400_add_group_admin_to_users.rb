class AddGroupAdminToUsers < ActiveRecord::Migration[8.0]
  def change
    add_column :users, :group_admin, :boolean, default: false, null: false
    add_index :users, :group_admin
  end
end

