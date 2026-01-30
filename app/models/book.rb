class Book < Item
  # Book-specific validations
  validates :author, presence: true, length: { minimum: 1, maximum: 255 }
  validates :genre, length: { maximum: 100 }, allow_blank: true
  validates :published_year, presence: true, numericality: { greater_than: 1800, less_than_or_equal_to: Date.current.year }
  validates :isbn, format: { with: /\A(?:\d{10}|\d{13})\z/, message: "must be 10 or 13 digits" }, allow_blank: true

  # Book-specific scopes
  scope :by_genre, ->(genre) { where(genre: genre) }
  scope :by_author, ->(author) { where("author ILIKE ?", "%#{author}%") }
  scope :by_title, ->(title) { where("title ILIKE ?", "%#{title}%") }

  # Backward compatibility associations (will be updated when ItemRequest/GroupItemAvailability are created)
  has_many :book_requests, class_name: "ItemRequest", foreign_key: "item_id", dependent: :destroy
  has_many :group_book_availabilities, class_name: "GroupItemAvailability", foreign_key: "item_id", dependent: :destroy
  has_many :available_community_groups, through: :group_item_availabilities, source: :community_group

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
