class BookService
  attr_accessor :book
  attr_reader :errors, :book_cannot_be_requested_by_reason

  def initialize(book = nil)
    @book = book
    @errors = []
    @item_service = ItemService.new(book)
  end

  def create_book(user, book_params)
    # Set genre to "Other" if empty
    book_params[:genre] = "Other" if book_params[:genre].blank?

    @book = @item_service.create_item(user, book_params, Book)
    @errors = @item_service.errors
    @book
  end

  def update_book(user, book_params)
    # Set genre to "Other" if empty
    book_params[:genre] = "Other" if book_params[:genre].blank?

    @item_service.item = @book
    result = @item_service.update_item(user, book_params)
    @errors = @item_service.errors
    result
  end

  def remove_book(current_user)
    @item_service.item = @book
    result = @item_service.remove_item(current_user)
    @errors = @item_service.errors
    result
  end

  def search_books(base_scope: Book.available, query_string: nil, zip_code: nil, radius: nil, community_group_id: nil, sub_group_id: nil)
    @item_service.item = nil
    @item_service.search_items(
      base_scope: base_scope,
      query_string: query_string,
      zip_code: zip_code,
      radius: radius,
      community_group_id: community_group_id,
      sub_group_id: sub_group_id
    )
  end

  def track_book_view(current_user)
    @item_service.item = @book
    @item_service.track_item_view(current_user)
  end

  def community_stats(zip_code: nil, radius: nil, community_group_id: nil, sub_group_id: nil)
    base_books = search_books(base_scope: Book, zip_code: zip_code, radius: radius, community_group_id: community_group_id, sub_group_id: sub_group_id)
    base_requests = ItemRequest.joins(:item).merge(base_books)

    {
      books_shared: base_books.where.not(status: ShareableItemStatus::DONATED).distinct.count(:id),
      books_donated: base_books.where(status: ShareableItemStatus::DONATED).distinct.count(:id),
      books_requested: base_requests.distinct.count(:id),
      happy_readers: base_requests.completed.distinct.count(:requester_id)
    }
  end

  def community_group_stats(community_group_id:, sub_group_id: nil)
    community_stats = community_stats(community_group_id: community_group_id, sub_group_id: sub_group_id)

    membership_scope = CommunityGroupMembership.where(community_group_id: community_group_id)
    if sub_group_id.present?
      # Filter by the owner's membership subgroup for this community group.
      membership_scope = membership_scope.where(sub_group_id: sub_group_id)
    end

    community_stats.merge(members: membership_scope.distinct.count(:user_id))
  end

  def book_can_be_requested_by?(user)
    @item_service.item = @book
    result = @item_service.item_can_be_requested_by?(user)
    @book_cannot_be_requested_by_reason = @item_service.item_cannot_be_requested_by_reason
    result
  end

  def book_json(book, requester = nil)
    # Get community groups in one query
    community_groups = book.available_community_groups.to_a
    community_group_ids = []
    community_group_names = []
    community_groups.each do |grp|
      community_group_ids << grp.id
      community_group_names << (grp.short_name == CommunityGroup::ZIPCODE_SHORT_NAME ? "#{book.user.zip_code} Community" : grp.name)
    end

    result = {
      id: book.id,
      title: book.title,
      author: book.author,
      condition: book.condition,
      summary: book.summary,
      isbn: book.isbn,
      genre: book.genre,
      published_year: book.published_year,
      status: book.status,
      status_display: ShareableItemStatus.display_status(book.status),
      cover_image_url: book.cover_image.attached? ? book.cover_image.attachment.url : nil,
      user_images_urls: book.user_images.attached? ? book.user_images.map { |img| img.url } : [],
      view_count: book.view_count || 0,
      personal_note: book.personal_note,
      pickup_method: book.pickup_method,
      pickup_address: book.pickup_address,
      community_group_ids: community_group_ids,
      community_group_names: community_group_names,
      owner: {
        id: book.user.id,
        name: book.user.display_name,
        location: book.user.location,
        verified: book.user.verified?,
        trust_score: book.user.trust_score || 0
      },
      request_count: book.item_requests.count,
      created_at: book.created_at,
      updated_at: book.updated_at,
      can_request: book_can_be_requested_by?(requester)
    }
    if @book_cannot_be_requested_by_reason.present?
      result[:can_request_reason] = @book_cannot_be_requested_by_reason
    end
    result
  end
end
