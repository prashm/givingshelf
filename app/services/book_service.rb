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

    @book = user.books.build(book_params)
    if @book.save
        handle_api_cover_image(api_cover_image)
        if user_images.present?
          Array(user_images).each do |image|
              self.book.user_images.attach(image) if image.present?
          end
        end
    else
      @errors += @book.errors.full_messages
      @book = nil
    end
    @book
  rescue => e
      @errors << e.message
      @book = nil
  end

  def update_book(user, book_params)
    raise "Not authorized" if self.book.user != user

    # Exclude any image attributes if present. They're handled separately after saving the book.
    api_cover_image = book_params.delete(:cover_image)
    user_images = book_params.delete(:user_images)
    remove_user_image_indices = book_params.delete(:remove_user_image_indices)

    if self.book.update(book_params)

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
        true
    else
      @errors += self.book.errors.full_messages
      false
    end
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

  def search_books(query_string: nil, zip_code: nil)
    books = Book.available.joins(:user)

    if query_string.present?
      books = books.where("books.title ILIKE :query OR books.author ILIKE :query", query: "%#{query_string}%")
    end

    if zip_code.present?
      books = books.where(users: { zip_code: zip_code })
      # Order by matching zip_code first, then by created_at
      books = books.order(
        Arel.sql("CASE WHEN users.zip_code = #{ActiveRecord::Base.connection.quote(zip_code)} THEN 0 ELSE 1 END"),
        created_at: :desc
      )
    else
      books = books.order(created_at: :desc)
    end

    books
  end

  def track_book_view(current_user)
    # Only increment view count if the viewer is not the book owner
    unless self.book.owner?(current_user)
      self.book.increment!(:view_count)
    end
    self.book.view_count
  end

  def self.community_stats(zip_code: nil)
    base_books = Book.joins(:user)
    base_requests = BookRequest.joins(book: :user)

    if zip_code.present?
      base_books = base_books.where(users: { zip_code: zip_code })
      base_requests = base_requests.where(users: { zip_code: zip_code })
    end

    {
      books_shared: base_books.where.not(status: Book::DONATED_STATUS).count,
      books_donated: base_books.where(status: Book::DONATED_STATUS).count,
      books_requested: base_requests.count,
      happy_readers: base_requests.completed.distinct.count(:requester_id)
    }
  end

  def book_json(book, requester = nil)
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
      status_display: display_status(book.status),
      cover_image_url: book.cover_image.attached? ? book.cover_image.attachment.url : nil,
      user_images_urls: book.user_images.attached? ? book.user_images.map { |img| img.url } : [],
      view_count: book.view_count || 0,
      owner: {
        id: book.user.id,
        name: book.user.display_name,
        location: book.user.location,
        verified: book.user.verified?
      },
      request_count: book.book_requests.count,
      created_at: book.created_at,
      updated_at: book.updated_at,
      can_request: book.can_be_requested_by?(requester)
    }
  end

  private

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

  def display_status(status)
    case status
    when Book::REQUESTED_STATUS
      "Requested"
    when Book::DONATED_STATUS
      "Donated"
    else
      "Available"
    end
  end
end
