require "open-uri"

class ItemService
  attr_accessor :item
  attr_reader :errors, :item_cannot_be_requested_by_reason, :item_request, :joined_existing

  # A wish can be joined while it's open, or fulfilled and not yet donated.
  JOINABLE_WISH_STATUSES = [ ShareableItemStatus::WISHLIST, ShareableItemStatus::AVAILABLE, ShareableItemStatus::REQUESTED ].freeze
  # Requests whose requester is still waiting on a wish, open or fulfilled.
  WAITING_REQUEST_STATUSES = [ ItemRequest::PENDING_STATUS, ItemRequest::IN_REVIEW_STATUS, ItemRequest::ACCEPTED_STATUS ].freeze
  # The owner's note when deleting an item follows a fixed text in one message (max 1000 characters).
  REMOVAL_NOTE_MAX = 900
  ACCEPTED_REQUEST_BLOCKS_REMOVAL = "You have an accepted request for this item. Decline or complete it first.".freeze
  DONATED_ITEM_CANT_BE_REMOVED = "A donated item can't be deleted. It stays in your items as a record of the handoff.".freeze
  # Lower-cased, trimmed, with runs of whitespace collapsed; see #normalize_wish_text.
  NORMALIZED_WISH_SQL = {
    "title" => "regexp_replace(lower(btrim(coalesce(items.title, ''))), '\\s+', ' ', 'g')",
    "author" => "regexp_replace(lower(btrim(coalesce(items.author, ''))), '\\s+', ' ', 'g')",
    "brand" => "regexp_replace(lower(btrim(coalesce(items.brand, ''))), '\\s+', ' ', 'g')"
  }.freeze

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

  def update_item(owner, item_params)
    raise "Item can't be blank" unless self.item

    # Exclude any image attributes if present. They're handled separately after saving the item.
    api_cover_image = item_params.delete(:cover_image)
    user_images = item_params.delete(:user_images)
    remove_user_image_indices = item_params.delete(:remove_user_image_indices)
    community_group_ids = item_params.delete(:community_group_ids)
    guard_wish_identity!(item_params, community_group_ids) if item.wishlist_item?

    ActiveRecord::Base.transaction do
      self.item.update!(item_params)
      # A wishlist item keeps its groups (and sub-groups); the guard above has refused any change.
      if community_group_ids.present? && !item.wishlist_item?
        community_group_ids = community_group_ids.to_h { |gid| [ gid.to_i, nil ] } if community_group_ids.is_a?(Array)
        sync_group_item_availabilities!(owner, community_group_ids)
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

  # Deletes the item for its owner (GS-12). Refused for a donated item (it's the record of a handoff)
  # and while a request is accepted. Otherwise the open requests get a final result first (declined,
  # or for a fulfilled wish, moved to a new wish), with the owner's optional note. An item that ever
  # had a request is then only marked deleted, so the requests and their threads survive; one that
  # never had a request is destroyed.
  def remove_item(current_user, note: nil)
    raise "Not authorized" unless item.owner?(current_user)
    raise "This item was already removed" if item.deleted?
    note = note.to_s.strip
    raise "Note is too long (maximum is #{REMOVAL_NOTE_MAX} characters)" if note.length > REMOVAL_NOTE_MAX

    ActiveRecord::Base.transaction do
      # Lock the item so no request can be accepted or added while it's being removed.
      item.lock!
      raise DONATED_ITEM_CANT_BE_REMOVED if item.donated?
      requests = item.item_requests.order(:created_at, :id).to_a
      raise ACCEPTED_REQUEST_BLOCKS_REMOVAL if requests.any?(&:accepted?)

      if requests.any?
        open_requests = requests.select { |request| ItemRequest::OPEN_STATUSES.include?(request.status) }
        ItemRequestService.new.close_out_requests!(item, open_requests, current_user,
          declined_note: ItemRequestService.note_after(ItemRequestService::ITEM_REMOVED_NOTE, note),
          moved_note: ItemRequestService.note_after(ItemRequestService::ITEM_REMOVED_MOVED_NOTE, note))
        item.update!(deleted_at: Time.current)
      else
        item.destroy!
      end
    end
    true
  rescue => e
    @errors << e.message
    false
  end

  # Creates a book with no owner (wishlist) plus the requester's pending ItemRequest.
  # If the same item is already wished for where the requester is, they join that wish instead:
  # no item is created, #item is the existing wish and #joined_existing is true.
  def create_wishlist_item(requester, params)
    raise "User profile is incomplete." unless requester.profile_complete?
    item_params = params.to_h.with_indifferent_access
    cover_image_url = item_params.delete(:cover_image_url)
    cg_id = item_params.delete(:community_group_id)
    sg_id = item_params.delete(:sub_group_id)
    message = item_params.delete(:message).to_s.strip
    message = self.class::DEFAULT_WISHLIST_MESSAGE if message.blank?
    raise "Invalid community group selection" if cg_id.blank?
    message_error = ItemRequestService.initial_message_error(message)
    raise message_error if message_error

    community_group_ids = { cg_id.to_s => sg_id }
    validate_requested_groups_for(requester, community_group_ids)
    if @errors.blank?
      ActiveRecord::Base.transaction do
        # Serialize wishes for the same title in the group, so two wishers can't both miss the match.
        lock_wish_key!(cg_id, item_params[:title])
        sub_group_id = requester.group_memberships[cg_id.to_i]
        match = find_matching_wish(requester, item_params, cg_id, sub_group_id)
        if match
          join_wish!(requester, match, message)
        else
          create_wish!(requester, item_params, community_group_ids, cover_image_url, message)
        end
      end
    end
    @item
  rescue => e
    @errors << e.message
    nil
  end

  # The wish this requester would duplicate: same type and identity (see #wish_identity_scope),
  # in that group and where the requester is (see #wish_location_scope), still open or fulfilled
  # but not donated, with someone still waiting. Oldest first.
  def find_matching_wish(requester, attrs, community_group_id, sub_group_id)
    attrs = attrs.to_h.with_indifferent_access
    candidates = type_class
      # Started as a wish, and is still open or fulfilled but not donated.
      .where(wishlist_item: true, status: JOINABLE_WISH_STATUSES)
      # Not something the requester is giving away themselves (they'd donated a fulfilled wish).
      .where("items.user_id IS NULL OR items.user_id <> ?", requester.id)
      # Shared in the requested group.
      .joins(:group_item_availabilities)
      .where(group_item_availabilities: { community_group_id: community_group_id })
      # Someone is still waiting on it.
      .where("EXISTS (SELECT 1 FROM item_requests waiting WHERE waiting.item_id = items.id AND waiting.status IN (?))", WAITING_REQUEST_STATUSES)
    candidates = wish_identity_scope(candidates, attrs)
    candidates = wish_location_scope(candidates, requester, community_group_id, sub_group_id)
    candidates.order(:created_at, :id).first
  end

  # Assigns donor to wishlist book and sets item to available. Notifies all the requesters of the item.
  def fulfill_wishlist_item(donor_user, item_params)
    data = item_params.to_h.merge(user_id: donor_user.id, status: ShareableItemStatus::AVAILABLE).with_indifferent_access
    # update_item rescues its own errors, so roll back explicitly when it fails; otherwise a
    # failure while matching requests would leave the item AVAILABLE with requests still pending.
    matched_requests = []
    updated = false
    ActiveRecord::Base.transaction do
      # Lock the wish so the checks below can't race another donor or a requester cancelling.
      @item.lock!
      unless @item.wishlist?
        raise(@item.wishlist_item? ? "Another donor just fulfilled this wish" : "Not a wishlist item")
      end
      # Any request counts, cancelled ones too: a donor who also wished for the item would otherwise
      # end up owning their own (uncancellable) request.
      if @item.item_requests.where(requester_id: donor_user.id).exists?
        raise "You cannot fulfill your own wishlist request"
      end
      raise "No one is waiting for this item anymore" unless @item.item_requests.active_wish.exists?
      raise ActiveRecord::Rollback unless update_item(donor_user, data)
      @item.item_requests.pending.each do |pending_req|
        ItemRequestService.new(pending_req).match_wishlist_donor!(donor_user)
        matched_requests << pending_req
      end
      updated = true
    end
    return false unless updated

    # Notify only after the transaction has committed
    matched_requests.each do |req|
      UserService.new.notify_wishlist_available_to_requester(item: @item, item_request: req)
    end
    true
  rescue => e
    @errors << e.message
    false
  end

  # Item details a relisted wish copies from the donated item.
  WISH_COPY_ATTRIBUTES = %w[type title author brand isbn genre published_year age_range min_age max_age summary].freeze

  # Creates a new ownerless wish for the same item, in the same groups.
  # Called when a fulfilled wish is donated and other wishers are still waiting.
  def relist_as_wish!
    raise "Item did not start as a wish" unless item.wishlist_item?

    wish = Item.create!(item.attributes.slice(*WISH_COPY_ATTRIBUTES).merge("status" => ShareableItemStatus::WISHLIST))
    wish.cover_image.attach(item.cover_image.blob) if item.cover_image.attached?
    now = Time.current
    rows = item.group_item_availabilities.pluck(:community_group_id, :sub_group_id).map do |group_id, sub_group_id|
      { item_id: wish.id, community_group_id: group_id, sub_group_id: sub_group_id, created_at: now, updated_at: now }
    end
    GroupItemAvailability.insert_all(rows) if rows.any?
    wish
  end

  def available_items
    type_class.available.includes(:user).recent
  end

  # Override in subclasses (e.g. BookService) for type-specific query matching.
  def apply_query_filter(items, query)
    items.where(
      "items.title ILIKE :query OR items.author ILIKE :query OR items.brand ILIKE :query",
      query: "%#{ActiveRecord::Base.sanitize_sql_like(query)}%"
    )
  end

  def search_items(base_scope:, query_string: nil, zip_code: nil, radius: nil, community_group_id: nil, sub_group_id: nil, age_range: nil, user_join_type: :owner)
    items = base_scope.joins(:group_item_availabilities)
    
    normalized_query = query_string.to_s.strip

    items = apply_query_filter(items, normalized_query) if normalized_query.present?

    # Determine if we should apply ZIP code filtering
    apply_zip_filter = false
    
    # Filter by community group availability
    if community_group_id.present?
      items = items.where(group_item_availabilities: { community_group_id: community_group_id })

      if sub_group_id.present?
        # Keep existing owner-membership based subgroup filtering, but also support
        # subgroup scoping on availability rows (needed for ownerless wishlist items).
        sub_group_sql = "(community_group_memberships.community_group_id = :community_group_id AND community_group_memberships.sub_group_id = :sub_group_id) OR group_item_availabilities.sub_group_id = :sub_group_id"
        if user_join_type == :requester
          # A wish also shows in a sub-group when someone still waiting on it belongs to that
          # sub-group, the way ZIP matching follows its requesters (`requesters` is joined below).
          sub_group_sql += " OR EXISTS (SELECT 1 FROM community_group_memberships requester_memberships" \
                           " WHERE requester_memberships.user_id = requesters.id" \
                           " AND requester_memberships.community_group_id = :community_group_id" \
                           " AND requester_memberships.sub_group_id = :sub_group_id)"
        end
        items = items.left_outer_joins(user: :community_group_memberships)
                     .where(sub_group_sql, community_group_id: community_group_id, sub_group_id: sub_group_id)
      end
    else
      # Default browse/search behavior: only show items available in the ZIP Code Community group.
      items = items.where(group_item_availabilities: { community_group_id: CommunityGroup.find_or_create_zipcode_group!.id })
      apply_zip_filter = true
    end
    
    if zip_code.present? && apply_zip_filter
      items = apply_user_join(items, user_join_type)
      items = items.merge(zip_code_scope(zip_code, radius, user_join_type))
    else
      # Always join for :requester too, so wishes nobody is waiting on are hidden on every path.
      items = apply_user_join(items, user_join_type)
    end

    items = items.merge(Item.overlapping_age_bucket(age_range)) if age_range.present?

    items.distinct
  end

  def wishlist_items(zip_code: nil, radius: nil, community_group_id: nil, sub_group_id: nil, query_string: nil, age_range: nil)
    search_items(
      base_scope: type_class.wishlist,
      query_string: query_string,
      zip_code: zip_code,
      radius: radius,
      community_group_id: community_group_id,
      sub_group_id: sub_group_id,
      age_range: age_range,
      user_join_type: :requester
    )
  end

  def community_stats(zip_code: nil, radius: nil, community_group_id: nil, sub_group_id: nil)
    base_items = search_items(base_scope: type_class, zip_code: zip_code, radius: radius, community_group_id: community_group_id, sub_group_id: sub_group_id)
    wishlisted_items = wishlist_items(zip_code: zip_code, radius: radius, community_group_id: community_group_id, sub_group_id: sub_group_id)
    base_requests = ItemRequest.joins(:item).merge(base_items)

    {
      items_shared: base_items.where.not(status: [ ShareableItemStatus::DONATED, ShareableItemStatus::WISHLIST ]).distinct.count(:id),
      items_donated: base_items.where(status: ShareableItemStatus::DONATED).distinct.count(:id),
      items_requested: base_requests.distinct.count(:id),
      happy_users: base_requests.completed.distinct.count(:requester_id),
      items_wishlisted: wishlisted_items.distinct.count(:id)
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
    return false unless item.open_to_requests?
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

  # Detail JSON for one item. The shared fields are built here; BookService/ToyService add their
  # own through #type_fields. Called on a plain ItemService, it hands off to the typed service.
  def item_detail_map(item, requester = nil)
    return typed_service_for(item).item_detail_map(item, requester) if instance_of?(ItemService)

    group_ids, group_names = community_group_ids_and_names(item)
    result = {
      id: item.id,
      type: item.type,
      title: item.title,
      condition: item.condition,
      summary: item.summary,
      status: item.status,
      status_display: ShareableItemStatus.display_status(item.status),
      wishlist_item: item.wishlist_item,
      deleted: item.deleted?,
      cover_image_url: cover_image_url_for(item),
      user_images_urls: item.user_images.attached? ? item.user_images.map(&:url) : [],
      view_count: item.view_count || 0,
      personal_note: item.personal_note,
      pickup_method: item.pickup_method,
      pickup_address: item.pickup_address,
      community_group_ids: group_ids,
      community_group_names: group_names,
      owner: item.user ? {
        id: item.user.id,
        name: item.user.display_name,
        location: item.user.location,
        verified: item.user.verified?,
        trust_score: item.user.trust_score || 0
      } : nil,
      request_count: item.item_requests.where.not(status: ItemRequest::CANCELLED_STATUS).count,
      created_at: item.created_at,
      updated_at: item.updated_at,
      can_request: item_can_be_requested_by?(requester)
    }.merge(type_fields(item, detail: true))
    if @user_request
      result[:user_request_id] = @user_request.id
      result[:user_request_dt] = @user_request.created_at
      result[:user_request_status] = ItemRequestService.new.display_status(@user_request.status)
      result[:user_request_updated_at] = @user_request.updated_at
      actions = ItemRequestService.new.requester_actions(@user_request)
      result[:user_request_can_cancel] = actions[:can_cancel]
      result[:user_request_can_uncancel] = actions[:can_uncancel]
    end
    if @item_cannot_be_requested_by_reason.present?
      result[:cannot_request_reason] = @item_cannot_be_requested_by_reason
    end
    result
  end

  # List JSON for one of the owner's items (My Items), with what deleting needs: whether it can be
  # deleted at all (not once donated), how many requests are still waiting on it, and whether one is
  # accepted (which blocks deleting it for now). Expects item_requests preloaded.
  def my_item_map(item)
    requests = item.item_requests.to_a
    item_map(item).merge(
      can_delete: !item.donated?,
      open_request_count: requests.count { |request| ItemRequest::OPEN_STATUSES.include?(request.status) },
      has_accepted_request: requests.any?(&:accepted?)
    )
  end

  # List JSON for one item, built the same way as #item_detail_map.
  def item_map(item)
    return typed_service_for(item).item_map(item) if instance_of?(ItemService)

    {
      id: item.id,
      type: item.type,
      title: item.title,
      summary: item.summary,
      condition: item.condition,
      status: item.status,
      status_display: ShareableItemStatus.display_status(item.status),
      wishlist_item: item.wishlist_item,
      cover_image_url: cover_image_url_for(item),
      created_at: item.created_at
    }.merge(type_fields(item, detail: false))
  end

  private

  # Type-specific JSON fields; BookService and ToyService override this.
  def type_fields(_item, detail:)
    {}
  end

  def typed_service_for(item)
    raise "Invalid item type: #{item&.type}" unless Item.valid_type?(item&.type)
    ItemService.get_service(item.type, item)
  end

  def cover_image_url_for(item)
    item.cover_image.attached? ? item.cover_image.attachment.url : nil
  end

  def community_group_ids_and_names(item)
    groups = item.available_community_groups.to_a
    names = groups.map { |group| group.short_name == CommunityGroup::ZIPCODE_SHORT_NAME ? zip_community_name(item) : group.name }
    [ groups.map(&:id), names ]
  end

  # An open wish is shown to members near its requesters, so its ZIP group is named after their
  # ZIP codes. Any other item is shown by its owner's ZIP code.
  def zip_community_name(item)
    zips = item.wishlist? ? item.requesters.pluck("users.zip_code") : [ item.user&.zip_code ]
    zips = zips.compact_blank.uniq.sort
    zips.any? ? "#{zips.join(', ')} Community" : "ZIP Code Community"
  end

  # A new ownerless wish in the requester's group, with their pending request.
  def create_wish!(requester, item_params, community_group_ids, cover_image_url, message)
    @item = Item.create!(item_params.merge(type: type_class.name, status: ShareableItemStatus::WISHLIST))
    sync_group_item_availabilities!(requester, community_group_ids)
    handle_api_cover_image(cover_image_url)
    @item_request = ItemRequestService.new.start_request!(requester, @item, message)
  end

  # Adds the requester to an existing wish. Raises (rolling back) if they can't request it,
  # e.g. "You already requested this item".
  def join_wish!(requester, wish, message)
    wish.lock!
    request_service = ItemRequestService.new
    request = request_service.create_request(requester, wish.id, message)
    raise request_service.errors.first || "Could not join this wish" unless request
    @item = wish
    @item_request = request
    @joined_existing = true
  end

  def lock_wish_key!(community_group_id, title)
    key = "wish:#{type_class.name}:#{community_group_id}:#{normalize_wish_text(title)}"
    ActiveRecord::Base.connection.execute(
      ActiveRecord::Base.sanitize_sql_array([ "SELECT pg_advisory_xact_lock(hashtext(?))", key ])
    )
  end

  def normalize_wish_text(value)
    value.to_s.strip.downcase.gsub(/\s+/, " ")
  end

  # Same title and same creator. BookService also matches on ISBN.
  def wish_identity_scope(scope, attrs)
    scope = scope.where("#{NORMALIZED_WISH_SQL.fetch('title')} = ?", normalize_wish_text(attrs[:title]))
    return scope unless (creator = wish_creator_attribute)
    scope.where("#{NORMALIZED_WISH_SQL.fetch(creator)} = ?", normalize_wish_text(attrs[creator]))
  end

  # The column that, with the title, identifies an item: author for books, brand for toys.
  def wish_creator_attribute
    nil
  end

  # Where the requester is, using the same rule as browsing wishes. In the ZIP Code Community a
  # waiting requester must share their ZIP code. In any other group the wish must be in their
  # sub-group, or someone waiting on it must belong to that sub-group.
  def wish_location_scope(scope, requester, community_group_id, sub_group_id)
    if community_group_id.to_i == CommunityGroup.zipcode_group&.id
      return scope.where(<<~SQL.squish, WAITING_REQUEST_STATUSES, requester.zip_code)
        EXISTS (SELECT 1 FROM item_requests waiting
                JOIN users waiting_users ON waiting_users.id = waiting.requester_id
                WHERE waiting.item_id = items.id AND waiting.status IN (?) AND waiting_users.zip_code = ?)
      SQL
    end
    return scope.where(group_item_availabilities: { sub_group_id: nil }) if sub_group_id.blank?

    scope.where(<<~SQL.squish, sub_group_id: sub_group_id, statuses: WAITING_REQUEST_STATUSES, group_id: community_group_id)
      group_item_availabilities.sub_group_id = :sub_group_id
      OR EXISTS (SELECT 1 FROM item_requests waiting
                 JOIN community_group_memberships waiting_members ON waiting_members.user_id = waiting.requester_id
                 WHERE waiting.item_id = items.id AND waiting.status IN (:statuses)
                   AND waiting_members.community_group_id = :group_id AND waiting_members.sub_group_id = :sub_group_id)
    SQL
  end

  # Raises if the update would change a wishlist item's title, author or set of groups.
  # Sending the current values is fine, since edit forms send the whole record.
  def guard_wish_identity!(item_params, community_group_ids)
    attrs = item_params.to_h.with_indifferent_access
    changed = Item::WISH_LOCKED_ATTRIBUTES.any? do |attr|
      attrs.key?(attr) && attrs[attr].to_s != item[attr].to_s
    end
    if community_group_ids.present?
      requested = (community_group_ids.is_a?(Hash) ? community_group_ids.keys : Array(community_group_ids)).map(&:to_i).sort
      changed ||= requested != item.group_item_availabilities.pluck(:community_group_id).sort
    end
    raise "You're trying to edit a restricted field for this wishlist item" if changed
  end

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


  def apply_user_join(items, user_join_type)
    case user_join_type
    when :requester
      # Only requesters still waiting count: a wish whose requests are all cancelled is hidden,
      # and a cancelled requester's location doesn't match the zip/radius filter.
      active_requests_join = ActiveRecord::Base.sanitize_sql_array([
        "INNER JOIN item_requests ON item_requests.item_id = items.id AND item_requests.status IN (?)",
        ItemRequest::ACTIVE_WISH_STATUSES
      ])
      items.joins(active_requests_join)
           .joins("INNER JOIN users requesters ON requesters.id = item_requests.requester_id")
    when :owner
      items.left_outer_joins(:user)
    else
      raise ArgumentError, "Invalid user_join_type: #{user_join_type}"
    end
  end

  def zip_code_scope(zip_code, radius, user_join_type = :owner)
    user_table = user_join_type == :requester ? "requesters" : "users"
    
    if (radius_miles = radius.to_i) > 0
      address_verification_service = AddressVerificationService.new
      search_coords = address_verification_service.geocode_zip_code(zip_code)
      radius_scope = false
      if search_coords && search_coords[:latitude] && search_coords[:longitude]
        lat = search_coords[:latitude]
        lng = search_coords[:longitude]

        scope = Item.where(
          "(6371 * acos(GREATEST(-1.0, LEAST(1.0, cos(radians(?)) * cos(radians(#{user_table}.latitude)) * cos(radians(#{user_table}.longitude) - radians(?)) + sin(radians(?)) * sin(radians(#{user_table}.latitude)))))) * 0.621371 <= ? AND #{user_table}.latitude IS NOT NULL AND #{user_table}.longitude IS NOT NULL",
          lat, lng, lat, radius_miles
        )
        radius_scope = true
      else
        Rails.logger.warn "Geocoding failed for ZIP code #{zip_code}, falling back to exact match. Error: #{address_verification_service.errors.to_sentence}"
      end
    end
    unless radius_scope
      scope = Item.where("#{user_table}.zip_code" => zip_code)
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
