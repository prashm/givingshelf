class AddIndexToItemsIsbn < ActiveRecord::Migration[8.0]
  def change
    # Partial index: Toy rows (and other non-book items) have null isbn.
    add_index :items, :isbn, where: "isbn IS NOT NULL", name: "index_items_on_isbn"
  end
end
