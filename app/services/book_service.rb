class BookService < ItemService
  DEFAULT_WISHLIST_MESSAGE = "I'd love this book if anyone has a copy. Thanks!".freeze

  def search_items(base_scope: Book.available, query_string: nil, zip_code: nil, radius: nil, community_group_id: nil, sub_group_id: nil, age_range: nil, user_join_type: :owner)
    super(
      base_scope: base_scope,
      query_string: query_string,
      zip_code: zip_code,
      radius: radius,
      community_group_id: community_group_id,
      sub_group_id: sub_group_id,
      age_range: age_range,
      user_join_type: user_join_type
    )
  end

  # Exact ISBN-13 match when the query is an ISBN; otherwise title/author ILIKE.
  def apply_query_filter(items, query)
    isbn13 = Book.to_isbn13(query)
    return items.where(isbn: isbn13) if isbn13.present?

    super
  end

  private

  def type_fields(book, detail:)
    fields = { author: book.author, genre: book.genre, published_year: book.published_year }
    detail ? fields.merge(isbn: book.isbn) : fields
  end

  def type_class
    Book
  end
end
