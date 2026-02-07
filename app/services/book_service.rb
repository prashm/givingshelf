class BookService < ItemService
  def stats_base_scope
    Book.all
  end

  def available_items
    Book.available.includes(:user).recent
  end

  def search_items(base_scope: Book.available, query_string: nil, zip_code: nil, radius: nil, community_group_id: nil, sub_group_id: nil)
    super(
      base_scope: base_scope,
      query_string: query_string,
      zip_code: zip_code,
      radius: radius,
      community_group_id: community_group_id,
      sub_group_id: sub_group_id
    )
  end

  def item_map(book)
    {
      id: book.id,
      title: book.title,
      author: book.author,
      condition: book.condition,
      status: book.status,
      status_display: ShareableItemStatus.display_status(book.status),
      cover_image_url: book.cover_image.attached? ? book.cover_image.attachment.url : nil,
      created_at: book.created_at
    }
  end

  def item_detail_map(book, requester = nil)
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
      can_request: item_can_be_requested_by?(requester)
    }
    if @item_cannot_be_requested_by_reason.present?
      result[:can_request_reason] = @item_cannot_be_requested_by_reason
    end
    result
  end
end
