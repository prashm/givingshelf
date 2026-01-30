# Creates the items table (STI base for Book and Toy).
# Original migration created :books; we create :items so a fresh DB gets the STI schema.
class CreateItems < ActiveRecord::Migration[8.0]
  def change
    create_table :items do |t|
      t.string :type, null: false
      t.references :user, null: false, foreign_key: true
      t.string :title
      t.string :condition
      t.text :summary
      t.text :details
      t.text :meta
      t.string :cover_image
      t.string :isbn
      t.string :genre
      t.integer :published_year
      t.integer :status, default: 0, null: false
      t.integer :view_count, default: 0, null: false
      t.text :personal_note
      t.string :pickup_method
      t.text :pickup_address
      # Toy-specific (nullable for Book)
      t.string :brand
      t.string :age_range

      t.timestamps
    end

    add_index :items, :type
    add_index :items, :status
  end
end
