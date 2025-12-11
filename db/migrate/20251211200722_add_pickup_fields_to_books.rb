class AddPickupFieldsToBooks < ActiveRecord::Migration[8.0]
  def change
    add_column :books, :personal_note, :text
    add_column :books, :pickup_method, :string
    add_column :books, :pickup_address, :text
  end
end
