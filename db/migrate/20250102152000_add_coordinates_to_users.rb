class AddCoordinatesToUsers < ActiveRecord::Migration[8.0]
  def change
    add_column :users, :latitude, :decimal, precision: 10, scale: 7
    add_column :users, :longitude, :decimal, precision: 10, scale: 7
  end
end

