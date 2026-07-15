class AddMinMaxAgeToItems < ActiveRecord::Migration[8.0]
  def change
    add_column :items, :min_age, :integer
    add_column :items, :max_age, :integer
    add_index :items, [ :min_age, :max_age ]
  end
end
