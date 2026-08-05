class Book < Item
  # Canonical form is ISBN-13 so scanned barcodes and typed ISBN-10s converge.
  normalizes :isbn, with: ->(value) { Book.to_isbn13(value) }

  # Book-specific validations
  validates :author, presence: true, length: { minimum: 1, maximum: 255 }
  validates :genre, length: { maximum: 100 }, allow_blank: true
  validates :published_year, presence: true, numericality: { greater_than: 1800, less_than_or_equal_to: Date.current.year }
  validates :isbn, format: { with: /\A\d{13}\z/, message: "must be a valid ISBN" }, allow_blank: true

  # Book-specific scopes
  scope :by_genre, ->(genre) { where(genre: genre) }
  scope :by_author, ->(author) { where("author ILIKE ?", "%#{author}%") }
  scope :by_title, ->(title) { where("title ILIKE ?", "%#{title}%") }

  has_many :item_requests, class_name: "ItemRequest", foreign_key: "item_id", dependent: :destroy
  has_many :group_book_availabilities, class_name: "GroupItemAvailability", foreign_key: "item_id", dependent: :destroy
  has_many :available_community_groups, through: :group_item_availabilities, source: :community_group

  # Convert ISBN-10 (including trailing X) or dashed input to ISBN-13.
  # Returns nil for blank or unrecognized values.
  def self.to_isbn13(raw)
    chars = raw.to_s.upcase.gsub(/[^0-9X]/, "")
    return nil if chars.blank?
    return chars if chars.match?(/\A\d{13}\z/)
    return nil unless chars.length == 10

    core = "978#{chars[0, 9]}"
    sum = core.chars.each_with_index.sum { |digit, i| digit.to_i * (i.even? ? 1 : 3) }
    "#{core}#{(10 - (sum % 10)) % 10}"
  end

  # Ransack allowlist for ActiveAdmin search/filter
  def self.ransackable_attributes(auth_object = nil)
    %w[
      id id_value title author summary condition isbn genre published_year
      status view_count personal_note pickup_method pickup_address
      user_id created_at updated_at
    ]
  end

  def self.ransackable_associations(auth_object = nil)
    [ "item_requests", "user", "user_images" ]
  end
end
