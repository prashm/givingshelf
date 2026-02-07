class ToyService < ItemService
  def stats_base_scope
    Toy.all
  end

  def available_items
    Toy.available.includes(:user).recent
  end

  def search_items(base_scope: Toy.available, query_string: nil, zip_code: nil, radius: nil, community_group_id: nil, sub_group_id: nil)
    super(
      base_scope: base_scope,
      query_string: query_string,
      zip_code: zip_code,
      radius: radius,
      community_group_id: community_group_id,
      sub_group_id: sub_group_id
    )
  end

  def item_map(toy)
    {
      id: toy.id,
      title: toy.title,
      brand: toy.brand,
      age_range: toy.age_range,
      condition: toy.condition,
      status: toy.status,
      status_display: ShareableItemStatus.display_status(toy.status),
      cover_image_url: toy.cover_image.attached? ? toy.cover_image.attachment.url : nil,
      created_at: toy.created_at
    }
  end

  def item_detail_map(toy, requester = nil)
    # Get community groups in one query
    community_groups = toy.available_community_groups.to_a
    community_group_ids = []
    community_group_names = []
    community_groups.each do |grp|
      community_group_ids << grp.id
      community_group_names << (grp.short_name == CommunityGroup::ZIPCODE_SHORT_NAME ? "#{toy.user.zip_code} Community" : grp.name)
    end

    result = {
      id: toy.id,
      title: toy.title,
      brand: toy.brand,
      age_range: toy.age_range,
      condition: toy.condition,
      summary: toy.summary,
      status: toy.status,
      status_display: ShareableItemStatus.display_status(toy.status),
      cover_image_url: toy.cover_image.attached? ? toy.cover_image.attachment.url : nil,
      user_images_urls: toy.user_images.attached? ? toy.user_images.map { |img| img.url } : [],
      view_count: toy.view_count || 0,
      personal_note: toy.personal_note,
      pickup_method: toy.pickup_method,
      pickup_address: toy.pickup_address,
      community_group_ids: community_group_ids,
      community_group_names: community_group_names,
      owner: {
        id: toy.user.id,
        name: toy.user.display_name,
        location: toy.user.location,
        verified: toy.user.verified?,
        trust_score: toy.user.trust_score || 0
      },
      request_count: toy.item_requests.count,
      created_at: toy.created_at,
      updated_at: toy.updated_at,
      can_request: toy_can_be_requested_by?(requester)
    }
    if @toy_cannot_be_requested_by_reason.present?
      result[:can_request_reason] = @toy_cannot_be_requested_by_reason
    end
    result
  end
end
