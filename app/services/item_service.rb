require "open-uri"

class ItemService
  attr_accessor :item
  attr_reader :errors, :item_cannot_be_requested_by_reason, :item_request

  def initialize(item = nil)
    @item = item
    @errors = []
  end

  def self.get_service(item_type, item)
    type = item_type.presence || item&.type
    case type
    when Book.name
      BookService.new(item)
    when Toy.name
      ToyService.new(item)
    else
      ItemService.new(item)
    end
  end

  def create_item(user, item_params)
    item_type = item_params[:type]
    raise "Invalid item type: #{item_type}" unless Item.valid_type?(item_type)

    # Remove api_cover_image from item_params if present.
    # It's handled separately after saving the item.
    api_cover_image = item_params.delete(:cover_image)
    user_images = item_params.delete(:user_images)
    community_group_ids = item_params.delete(:community_group_ids)

    unless user.profile_complete?
      raise "User profile is incomplete."
    end

    @item = user.items.build(item_params.merge(type: item_type))
    ActiveRecord::Base.transaction do
      @item.save!

      community_group_ids = community_group_ids.to_h { |gid| [ gid.to_i, nil ] } if community_group_ids.is_a?(Array)
      sync_group_item_availabilities!(user, community_group_ids)

      handle_api_cover_image(api_cover_image)
      if user_images.present?
        Array(user_images).each do |image|
          if image.present?
            self.item.cover_image.attach(image) if self.item.cover_image.blank?
            self.item.user_images.attach(image)
          end
        end
      end
    end
    @item
  rescue => e
    @errors << e.message
    nil
  end

  def update_item(user, item_params)
    raise "Item can't be blank" unless self.item
    if self.item.user.present?
      raise "Not authorized" if self.item.user != user
    else
      raise "Not authorized" unless self.item.wishlist?
    end

    # Exclude any image attributes if present. They're handled separately after saving the item.
    api_cover_image = item_params.delete(:cover_image)
    user_images = item_params.delete(:user_images)
    remove_user_image_indices = item_params.delete(:remove_user_image_indices)
    community_group_ids = item_params.delete(:community_group_ids)

    ActiveRecord::Base.transaction do
      self.item.update!(item_params)
      if community_group_ids.present?
        community_group_ids = community_group_ids.to_h { |gid| [ gid.to_i, nil ] } if community_group_ids.is_a?(Array)
        sync_group_item_availabilities!(user, community_group_ids)
      end

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

  # Creates a book with no owner (wishlist) plus the requester's pending ItemRequest.
  def create_wishlist_item(requester, params)
    raise "User profile is incomplete." unless requester.profile_complete?
    item_params = params.to_h.with_indifferent_access
    cover_image_url = item_params.delete(:cover_image_url)
    cg_id = item_params.delete(:community_group_id)
    sg_id = item_params.delete(:sub_group_id)
    raise "Invalid community group selection" if cg_id.blank?

    community_group_ids = { cg_id.to_s => sg_id }
    validate_requested_groups_for(requester, community_group_ids)
    if @errors.blank?
      ActiveRecord::Base.transaction do
        @item = Item.create!(item_params.merge(type: type_class.name, status: ShareableItemStatus::WISHLIST))
        sync_group_item_availabilities!(requester, community_group_ids)
        handle_api_cover_image(cover_image_url)
        @item_request = ItemRequest.create!(
          item: @item,
          requester: requester,
          owner: nil,
          message: self.class::DEFAULT_WISHLIST_MESSAGE,
          status: ItemRequest::PENDING_STATUS
        )
      end
    end
    @item
  rescue => e
    @errors << e.message
    nil
  end

  # Assigns donor to wishlist book and sets item to available. Notifies all the requesters of the item.
  def fulfill_wishlist_item(donor_user, item_params)
    raise "Not a wishlist item" unless @item.wishlist?
    if @item.item_requests.where(requester_id: donor_user.id).where.not(status: ItemRequest::CANCELLED_STATUS).exists?
      raise "You cannot fulfill your own wishlist request"
    end

    data = item_params.to_h.merge(user_id: donor_user.id, status: ShareableItemStatus::AVAILABLE).with_indifferent_access
    if update_item(donor_user, data)
      @item.item_requests.pending.each do |pending_req|
        pending_req.match_wishlist_donor!(donor_user)
        UserService.new.notify_wishlist_available_to_requester(item: @item, item_request: pending_req)
      end
      true
    else
      false
    end
  rescue => e
    @errors << e.message
    false
  end

  def available_items
    type_class.available.includes(:user).recent
  end

  def search_items(base_scope:, query_string: nil, zip_code: nil, radius: nil, community_group_id: nil, sub_group_id: nil)
    items = base_scope.joins(:user, :group_item_availabilities)

    if query_string.present?
      # Search title, author (Book), and brand (Toy)
      items = items.where(
        "items.title ILIKE :query OR items.author ILIKE :query OR items.brand ILIKE :query",
        query: "%#{ActiveRecord::Base.sanitize_sql_like(query_string)}%"
      )
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

  def community_stats(zip_code: nil, radius: nil, community_group_id: nil, sub_group_id: nil)
    base_items = search_items(base_scope: type_class, zip_code: zip_code, radius: radius, community_group_id: community_group_id, sub_group_id: sub_group_id)
    base_requests = ItemRequest.joins(:item).merge(base_items)

    {
      items_shared: base_items.where.not(status: ShareableItemStatus::DONATED).distinct.count(:id),
      items_donated: base_items.where(status: ShareableItemStatus::DONATED).distinct.count(:id),
      items_requested: base_requests.distinct.count(:id),
      happy_users: base_requests.completed.distinct.count(:requester_id)
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

  def track_item_view(current_user)
    # Only increment view count if the viewer is not the item owner
    if self.item.user.blank? || !self.item.owner?(current_user)
      self.item.increment!(:view_count)
    end
    self.item.view_count
  end

  def item_can_be_requested_by?(user)
    @item_cannot_be_requested_by_reason = nil
    return false if user.nil?
    return false unless item.available? || item.wishlist?
    return false if item.user.present? && user == item.user
    @user_request = item.item_requests.find_by(requester: user)
    if @user_request
      raise "You already requested this item"
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

  def item_detail_map(item, requester = nil)
    # If you're here, then child service was not set during initialization.
    case item&.type
    when Book.name
      BookService.new.item_detail_map(item, requester)
    when Toy.name
      ToyService.new.item_detail_map(item, requester)
    else
      raise "Invalid item type: #{item&.type}"
    end
  end

  def item_map(item)
    # If you're here, then child service was not set during initialization.
    case item&.type
    when Book.name
      BookService.new.item_map(item)
    when Toy.name
      ToyService.new.item_map(item)
    else
      raise "Invalid item type: #{item&.type}"
    end
  end

  private

  def type_class
    Item
  end

  def sync_group_item_availabilities!(user, community_group_ids)
    raise "community_group_ids must be a hash" if community_group_ids.present? && !community_group_ids.is_a?(Hash)
    desired_community_group_ids = {}
    if community_group_ids.present?
      membership_pairs = user.group_memberships
      # Set sub group id to the membership sub group id if not provided.
      community_group_ids.each do |gid, sid|
        if membership_pairs.key?(gid.to_i)
          desired_community_group_ids[gid.to_i] = sid.present? ? sid.to_i : membership_pairs[gid.to_i]
        end
      end
    elsif (zip_group_id = CommunityGroup.zipcode_group&.id)
      desired_community_group_ids = { zip_group_id => nil }
    end

    ids = desired_community_group_ids.keys

    current_availabilities = GroupItemAvailability.where(item_id: self.item.id).to_a
    current_ids = current_availabilities.map(&:community_group_id)
    to_add = ids - current_ids
    to_remove = current_ids - ids

    if to_add.any?
      GroupItemAvailability.insert_all(
        to_add.map { |gid|
          {
            item_id: self.item.id,
            community_group_id: gid,
            sub_group_id: desired_community_group_ids[gid],
            created_at: Time.current,
            updated_at: Time.current
          }
        },
        unique_by: "index_gia_on_item_id_and_community_group_id"
      )
    end

    keep_ids = ids - to_add
    if keep_ids.any?
      current_availabilities.each do |availability|
        next unless keep_ids.include?(availability.community_group_id)
        desired_sub_group_id = desired_community_group_ids[availability.community_group_id]
        next if availability.sub_group_id == desired_sub_group_id

        availability.update!(sub_group_id: desired_sub_group_id)
      end
    end

    if to_remove.any?
      GroupItemAvailability.where(item_id: self.item.id, community_group_id: to_remove).delete_all
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
      uri = URI.parse(secure_url)
      return false unless uri.is_a?(URI::HTTP) || uri.is_a?(URI::HTTPS)

      # Fetch the image from the URL
      downloaded_image = uri.open(read_timeout: 10)

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

  # Validate the requested community group ids for the user.
  # Returns true if the requested community group ids are part of the user's group memberships. Otherwise, returns false and sets @errors.
  def validate_requested_groups_for(user, community_group_ids)
    # Check if the requested community group ids are valid for the user.
    raise "Invalid community group selection" if community_group_ids.blank?
    community_group_ids.each do |gid, sid|
      raise "Invalid community group selection" unless user.group_memberships.key?(gid.to_i)
      raise "Invalid subgroup selection" if sid.present? && user.group_memberships[gid.to_i] != sid.to_i
    end
    true
  rescue => e
    @errors << e.message
    false
  end
end
