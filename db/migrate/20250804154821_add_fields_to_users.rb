class AddFieldsToUsers < ActiveRecord::Migration[8.0]
  def change
    add_column :users, :first_name, :string
    add_column :users, :last_name, :string
    add_column :users, :zip_code, :string
    add_column :users, :phone, :string
    add_column :users, :verified, :boolean
    add_column :users, :latitude, :decimal, precision: 10, scale: 7
    add_column :users, :longitude, :decimal, precision: 10, scale: 7
  end
end
