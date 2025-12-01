class Book < ApplicationRecord
  belongs_to :user
  has_many :book_requests, dependent: :destroy
  has_one_attached :cover_image
  has_many_attached :user_images

  validates :title, presence: true, length: { minimum: 1, maximum: 255 }
  validates :author, presence: true, length: { minimum: 1, maximum: 255 }
  validates :condition, presence: true, inclusion: { in: %w[excellent good fair poor], message: "must be excellent, good, fair, or poor" }
  validates :summary, presence: true, length: { minimum: 10, maximum: 1000 }
  validates :genre, presence: true, length: { minimum: 1, maximum: 100 }
  validates :published_year, presence: true, numericality: { greater_than: 1800, less_than_or_equal_to: Date.current.year }
  validates :status, inclusion: { in: %w[available requested donated], default: "available" }
  validates :isbn, format: { with: /\A(?:\d{10}|\d{13})\z/, message: "must be 10 or 13 digits" }, allow_blank: true


  scope :available, -> { where(status: "available") }
  scope :by_genre, ->(genre) { where(genre: genre) }
  scope :by_author, ->(author) { where("author ILIKE ?", "%#{author}%") }
  scope :by_title, ->(title) { where("title ILIKE ?", "%#{title}%") }
  scope :by_condition, ->(condition) { where(condition: condition) }
  scope :recent, -> { order(created_at: :desc) }
  scope :nearby, ->(zip_code) { joins(:user).where(users: { zip_code: zip_code }) }


  def cover_image_url
    cover_image.attached? ? cover_image : nil
  end

  def distance_from(zip_code)
    return 0 if user.zip_code == zip_code
    # Simple distance calculation - in a real app, you'd use a geocoding service
    zip_code.to_s[0..1] == user.zip_code[0..1] ? 1 : 2
  end

  def can_be_requested_by?(user)
    return false if user.nil?
    return false unless available?
    return false if user == self.user
    return false if book_requests.exists?(requester: user, status: [ "pending", "accepted" ])
    true
  end

  def available?
    status == "available"
  end

  def requested?
    status == "requested"
  end

  def donated?
    status == "donated"
  end

  def owner?(current_user)
    current_user.present? && user == current_user
  end
end
