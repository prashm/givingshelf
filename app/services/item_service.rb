require "open-uri"

class ItemService
  attr_accessor :item
  attr_reader :errors, :item_cannot_be_requested_by_reason

  def initialize(item = nil)
    @item = item
    @errors = []
  end

  def create_item(user, item_params, item_class)
    # Remove api_cover_image from item_params if present.
    # It's handled separately after saving the item.
    api_cover_image = item_params.delete(:cover_image)
    user_images = item_params.delete(:user_images)
    community_group_ids = item_params.delete(:community_group_ids)

    unless user.profile_complete?
      raise "User profile is incomplete."
    end

    @item = user.items.build(item_params.merge(type: item_class.name))
    ActiveRecord::Base.transaction do
      @item.save!
      sync_group_item_availabilities!(user, community_group_ids)
      handle_api_cover_image(api_cover_image)
      if user_images.present?
        Array(user_images).each do |image|
          self.item.user_images.attach(image) if image.present?
        end
      end
    end
    @item
  rescue => e
    @errors << e.message
    nil
  end

  def update_item(user, item_params)
    raise "Not authorized" if self.item.user != user

    # Exclude any image attributes if present. They're handled separately after saving the item.
    api_cover_image = item_params.delete(:cover_image)
    user_images = item_params.delete(:user_images)
    remove_user_image_indices = item_params.delete(:remove_user_image_indices)
    community_group_ids = item_params.delete(:community_group_ids)

    ActiveRecord::Base.transaction do
      self.item.update!(item_params)
      sync_group_item_availabilities!(user, community_group_ids) unless community_group_ids.nil?

      handle_api_cover_image(api_cover_image)

      # Handle removed existing images
      if remove_user_image_indices.present?
        indices_to_remove = remove_user_image_indices.map(&:to_i)
        existing_images = self.item.user_images.to_a
        # Remove in reverse order to maintain correct indices
        indices_to_remove.sort.reverse.each do |index|
          existing_images[index].purge if existing_images[index]
        end
      end

      # Add new images if any were uploaded (merge with existing)
      if user_images.present?
        Array(user_images).each do |image|
          self.item.user_images.attach(image) if image.present?
        end
      end
    end
    true
  rescue => e
    @errors << e.message
    false
  end

  def remove_item(current_user)
    # Only the owner can delete their item
    raise "Not authorized" unless self.item.owner?(current_user)

    self.item.destroy
    true
  rescue => e
    @errors << e.message
    false
  end

  def search_items(base_scope:, query_string: nil, zip_code: nil, radius: nil, community_group_id: nil, sub_group_id: nil)
    items = base_scope.joins(:user, :group_item_availabilities)

    if query_string.present?
      items = items.where("items.title ILIKE :query", query: "%#{query_string}%")
    end

    # Filter by community group availability
    if community_group_id.present?
      items = items.where(group_item_availabilities: { community_group_id: community_group_id })

      if sub_group_id.present?
        # Filter by the owner's membership subgroup for this community group.
        items = items.joins(user: :community_group_memberships)
                     .where(community_group_memberships: { community_group_id: community_group_id, sub_group_id: sub_group_id })
      end
    else
      # Default browse/search behavior: only show items available in the ZIP Code Community group.
      items = items.where(group_item_availabilities: { community_group_id: CommunityGroup.find_or_create_zipcode_group!.id })
      items = items.merge(zip_code_scope(zip_code, radius)) if zip_code.present?
    end

    items.distinct
  end

  def track_item_view(current_user)
    # Only increment view count if the viewer is not the item owner
    unless self.item.owner?(current_user)
      self.item.increment!(:view_count)
    end
    self.item.view_count
  end

  def item_can_be_requested_by?(user)
    @item_cannot_be_requested_by_reason = nil
    return false if user.nil?
    return false unless item.available?
    return false if user == item.user
    if item.item_requests.exists?(requester: user, status: [ ItemRequest::PENDING_STATUS, ItemRequest::ACCEPTED_STATUS ])
      raise "You have a pending or accepted request for this item"
    end

    # Check if user is in any of the groups the item is shared in
    item_group_ids = item.group_item_availabilities.pluck(:community_group_id)
    if item_group_ids.empty?
      raise "This item is not shared in any groups"
    end

    user_group_ids = user.community_group_memberships.pluck(:community_group_id)
    if !(item_group_ids & user_group_ids).any?
      raise "You are not a member of any groups this item is shared in"
    end

    true
  rescue => e
    @item_cannot_be_requested_by_reason = e.message
    false
  end

  private

  def sync_group_item_availabilities!(user, community_group_ids)
    zip_group = CommunityGroup.zipcode_group
    default_ids = zip_group ? [ zip_group.id ] : []

    ids =
      if community_group_ids.nil?
        default_ids
      else
        Array(community_group_ids).map(&:to_i).select { |id| id > 0 }.uniq
      end

    member_group_ids = user.community_groups.pluck(:id)
    unless (ids - member_group_ids).empty?
      raise "Invalid community group selection"
    end

    current_ids = self.item.group_item_availabilities.pluck(:community_group_id)
    to_add = ids - current_ids
    to_remove = current_ids - ids

    if to_add.any?
      GroupItemAvailability.insert_all(
        to_add.map { |gid| { item_id: self.item.id, community_group_id: gid, created_at: Time.current, updated_at: Time.current } },
        unique_by: "index_gia_on_item_id_and_community_group_id"
      )
    end

    if to_remove.any?
      self.item.group_item_availabilities.where(community_group_id: to_remove).delete_all
    end
  end

  def zip_code_scope(zip_code, radius)
    if (radius_miles = radius.to_i) > 0
      address_verification_service = AddressVerificationService.new
      search_coords = address_verification_service.geocode_zip_code(zip_code)
      radius_scope = false
      if search_coords && search_coords[:latitude] && search_coords[:longitude]
        # Use SQL Haversine formula to calculate distance
        # Formula: (6371 * acos(cos(radians(lat1)) * cos(radians(lat2)) * cos(radians(lng2) - radians(lng1)) + sin(radians(lat1)) * sin(radians(lat2)))) * 0.621371
        # 6371 = Earth's radius in km, 0.621371 converts km to miles
        # Use GREATEST/LEAST to clamp acos input to [-1, 1] to avoid floating point precision errors
        lat = search_coords[:latitude]
        lng = search_coords[:longitude]

        scope = Item.where(
          "(6371 * acos(GREATEST(-1.0, LEAST(1.0, cos(radians(?)) * cos(radians(users.latitude)) * cos(radians(users.longitude) - radians(?)) + sin(radians(?)) * sin(radians(users.latitude)))))) * 0.621371 <= ? AND users.latitude IS NOT NULL AND users.longitude IS NOT NULL",
          lat, lng, lat, radius_miles
        )
        radius_scope = true
      else
        # If geocoding fails, fall back to exact ZIP match
        Rails.logger.warn "Geocoding failed for ZIP code #{zip_code}, falling back to exact match. Error: #{address_verification_service.errors.to_sentence}"
      end
    end
    unless radius_scope
      # Exact ZIP code match (default behavior)
      scope = Item.where(users: { zip_code: zip_code })
    end
    scope
  end

  def handle_api_cover_image(api_url)
    # Only process if it's a string URL, not a File object
    return false if api_url.blank? || !api_url.is_a?(String) || !api_url.match?(/\Ahttps?:\/\//)

    begin
      # Ensure URL uses HTTPS
      secure_url = api_url.gsub(/^http:/, "https:")

      # Fetch the image from the URL
      downloaded_image = URI.open(secure_url, read_timeout: 10)

      # Determine content type from response or default to jpeg
      content_type = downloaded_image.content_type || "image/jpeg"
      extension = content_type.split("/").last || "jpg"
      filename = "cover_image_#{SecureRandom.hex(8)}.#{extension}"

      # Attach the downloaded image to the item
      self.item.cover_image.attach(
        io: downloaded_image,
        filename: filename,
        content_type: content_type
      )
    rescue => e
      @errors << "Failed to download cover image from #{api_url}: #{e.message}"
      false
    end
    true
  end
end
