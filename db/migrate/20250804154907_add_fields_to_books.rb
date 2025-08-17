class AddFieldsToBooks < ActiveRecord::Migration[8.0]
  def change
    add_reference :books, :user, null: false, foreign_key: true
    add_column :books, :condition, :string
    add_column :books, :summary, :text
    add_column :books, :cover_image, :string
    add_column :books, :isbn, :string
    add_column :books, :genre, :string
    add_column :books, :published_year, :integer
    add_column :books, :status, :string, default: 'available'
  end
end
