class BackfillItemsIsbnToIsbn13 < ActiveRecord::Migration[8.0]
  def up
    Book.where.not(isbn: [ nil, "" ]).find_each do |book|
      next if book.isbn.to_s.match?(/\A\d{13}\z/)

      isbn13 = Book.to_isbn13(book.isbn)
      if isbn13.present?
        book.update_columns(isbn: isbn13)
      end
    end
  end

  def down
    # Irreversible: original ISBN-10 forms are not retained after conversion.
  end
end
