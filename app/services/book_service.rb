require "open-uri"

class BookService
  attr_accessor :book
  attr_reader :errors

  def initialize(book = nil)
    @book = book
    @errors = []
  end

  def create_book(user, book_params)
    # Remove api_cover_image from book_params if present.
    # It's handled separately after saving the book.
    api_cover_image = book_params.delete(:cover_image)
    user_images = book_params.delete(:user_images)
    community_group_ids = book_params.delete(:community_group_ids)

    unless user.profile_complete?
      raise "User profile is incomplete."
    end

    # Set genre to "Other" if empty
    book_params[:genre] = "Other" if book_params[:genre].blank?

    @book = user.books.build(book_params)
    ActiveRecord::Base.transaction do
      @book.save!
      sync_group_book_availabilities!(user, community_group_ids)
      handle_api_cover_image(api_cover_image)
      if user_images.present?
        Array(user_images).each do |image|
          self.book.user_images.attach(image) if image.present?
        end
      end
    end
    @book
  rescue => e
    @errors << e.message
    nil
  end

  def update_book(user, book_params)
    raise "Not authorized" if self.book.user != user

    # Exclude any image attributes if present. They're handled separately after saving the book.
    api_cover_image = book_params.delete(:cover_image)
    user_images = book_params.delete(:user_images)
    remove_user_image_indices = book_params.delete(:remove_user_image_indices)
    community_group_ids = book_params.delete(:community_group_ids)

    # Set genre to "Other" if empty
    book_params[:genre] = "Other" if book_params[:genre].blank?

    ActiveRecord::Base.transaction do
      self.book.update!(book_params)
      sync_group_book_availabilities!(user, community_group_ids) unless community_group_ids.nil?

      handle_api_cover_image(api_cover_image)

      # Handle removed existing images
      if remove_user_image_indices.present?
        indices_to_remove = remove_user_image_indices.map(&:to_i)
        existing_images = self.book.user_images.to_a
        # Remove in reverse order to maintain correct indices
        indices_to_remove.sort.reverse.each do |index|
          existing_images[index].purge if existing_images[index]
        end
      end

      # Add new images if any were uploaded (merge with existing)
      if user_images.present?
        Array(user_images).each do |image|
          self.book.user_images.attach(image) if image.present?
        end
      end
    end
    true
  rescue => e
    @errors << e.message
    false
  end

  def remove_book(current_user)
    # Only the owner can delete their book
    raise "Not authorized" unless self.book.owner?(current_user)

    self.book.destroy
    true
  rescue => e
    @errors << e.message
    false
  end

  def search_books(query_string: nil, zip_code: nil, radius: nil, community_group_id: nil, sub_group_id: nil)
    books = Book.available.joins(:user, :group_book_availabilities)

    if query_string.present?
      books = books.where("books.title ILIKE :query OR books.author ILIKE :query", query: "%#{query_string}%")
    end

    # Filter by community group availability
    if community_group_id.present?
      books = books.where(group_book_availabilities: { community_group_id: community_group_id })

      if sub_group_id.present?
        # Filter by the owner's membership subgroup for this community group.
        books = books.joins(user: :community_group_memberships)
                     .where(community_group_memberships: { community_group_id: community_group_id, sub_group_id: sub_group_id })
      end
    else
      # Default browse/search behavior: only show books available in the ZIP Code Community group.
      books = books.where(group_book_availabilities: { community_group_id: CommunityGroup.zipcode_group.id })
      books = books.merge(zip_code_scope(zip_code, radius)) if zip_code.present?
    end

    books.distinct
  end

  def track_book_view(current_user)
    # Only increment view count if the viewer is not the book owner
    unless self.book.owner?(current_user)
      self.book.increment!(:view_count)
    end
    self.book.view_count
  end

  def community_stats(zip_code: nil, radius: nil)
    base_books = Book.joins(:user)
    base_requests = BookRequest.joins(book: :user)

    if zip_code.present?
      scope = zip_code_scope(zip_code, radius)
      base_books = base_books.merge(scope)
      base_requests = base_requests.merge(scope)
    end

    {
      books_shared: base_books.where.not(status: BookStatus::DONATED).count,
      books_donated: base_books.where(status: BookStatus::DONATED).count,
      books_requested: base_requests.count,
      happy_readers: base_requests.completed.distinct.count(:requester_id)
    }
  end

  def community_group_stats(community_group_id:, sub_group_id: nil)
    base_books = Book.joins(:user, :group_book_availabilities)
      .where(group_book_availabilities: { community_group_id: community_group_id })

    base_requests = BookRequest.joins(book: [ :user, :group_book_availabilities ])
      .where(group_book_availabilities: { community_group_id: community_group_id })

    membership_scope = CommunityGroupMembership.where(community_group_id: community_group_id)

    if sub_group_id.present?
      # Filter by the owner's membership subgroup for this community group.
      base_books = base_books.joins(user: :community_group_memberships)
        .where(community_group_memberships: { community_group_id: community_group_id, sub_group_id: sub_group_id })

      base_requests = base_requests.joins(book: { user: :community_group_memberships })
        .where(community_group_memberships: { community_group_id: community_group_id, sub_group_id: sub_group_id })

      membership_scope = membership_scope.where(sub_group_id: sub_group_id)
    end

    {
      books_shared: base_books.where.not(status: BookStatus::DONATED).distinct.count(:id),
      books_donated: base_books.where(status: BookStatus::DONATED).distinct.count(:id),
      books_requested: base_requests.distinct.count(:id),
      members: membership_scope.distinct.count(:user_id)
    }
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

    {
      id: book.id,
      title: book.title,
      author: book.author,
      condition: book.condition,
      summary: book.summary,
      isbn: book.isbn,
      genre: book.genre,
      published_year: book.published_year,
      status: book.status,
      status_display: BookStatus.display_status(book.status),
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
      request_count: book.book_requests.count,
      created_at: book.created_at,
      updated_at: book.updated_at,
      can_request: book.can_be_requested_by?(requester)
    }
  end


  private

  def sync_group_book_availabilities!(user, community_group_ids)
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

    current_ids = self.book.group_book_availabilities.pluck(:community_group_id)
    to_add = ids - current_ids
    to_remove = current_ids - ids

    if to_add.any?
      GroupBookAvailability.insert_all(
        to_add.map { |gid| { book_id: self.book.id, community_group_id: gid, created_at: Time.current, updated_at: Time.current } },
        unique_by: "index_gba_on_book_id_and_community_group_id"
      )
    end

    if to_remove.any?
      self.book.group_book_availabilities.where(community_group_id: to_remove).delete_all
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

        scope = Book.where(
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
      scope = Book.where(users: { zip_code: zip_code })
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

      # Attach the downloaded image to the book
      self.book.cover_image.attach(
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
