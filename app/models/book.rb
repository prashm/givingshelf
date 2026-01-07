class Book < ApplicationRecord
  belongs_to :user
  has_many :book_requests, dependent: :destroy
  has_one_attached :cover_image
  has_many_attached :user_images

  validates :title, presence: true, length: { minimum: 1, maximum: 255 }
  validates :author, presence: true, length: { minimum: 1, maximum: 255 }
  validates :condition, presence: true, inclusion: { in: %w[excellent good fair poor], message: "must be excellent, good, fair, or poor" }
  validates :summary, presence: true, length: { minimum: 10, maximum: 1000 }
  validates :genre, length: { maximum: 100 }, allow_blank: true
  validates :published_year, presence: true, numericality: { greater_than: 1800, less_than_or_equal_to: Date.current.year }
  validates :status, inclusion: { in: BookStatus.values, default: BookStatus::AVAILABLE }
  validates :isbn, format: { with: /\A(?:\d{10}|\d{13})\z/, message: "must be 10 or 13 digits" }, allow_blank: true


  scope :available, -> { where.not(status: BookStatus::DONATED) }
  scope :by_genre, ->(genre) { where(genre: genre) }
  scope :by_author, ->(author) { where("author ILIKE ?", "%#{author}%") }
  scope :by_title, ->(title) { where("title ILIKE ?", "%#{title}%") }
  scope :by_condition, ->(condition) { where(condition: condition) }
  scope :recent, -> { order(created_at: :desc) }
  scope :nearby, ->(zip_code) { joins(:user).where(users: { zip_code: zip_code }) }

  # Ransack allowlist for ActiveAdmin search/filter
  def self.ransackable_attributes(auth_object = nil)
    %w[
      id id_value title author summary condition isbn genre published_year
      status view_count personal_note pickup_method pickup_address
      user_id created_at updated_at
    ]
  end

  def self.ransackable_associations(auth_object = nil)
    [ "book_requests", "user", "user_images" ]
  end

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
    return false if book_requests.exists?(requester: user, status: [ BookRequest::PENDING_STATUS, BookRequest::ACCEPTED_STATUS ])
    true
  end

  def available?
    status == BookStatus::AVAILABLE
  end

  def requested?
    status == BookStatus::REQUESTED
  end

  def donated?
    status == BookStatus::DONATED
  end

  def owner?(current_user)
    current_user.present? && user == current_user
  end

  # Regenerate sitemap when books are created or updated
  # Using after_commit to ensure the database transaction is complete
  after_commit :regenerate_sitemap, on: [ :create, :update, :destroy ]

  private

  def regenerate_sitemap
    # Only regenerate in production or if explicitly enabled
    return unless Rails.env.production? || ENV["REGENERATE_SITEMAP"] == "true"

    # Regenerate sitemap in background to avoid blocking the request
    # Loading the config file will execute the SitemapGenerator::Sitemap.create block
    begin
      require "sitemap_generator"
      # Reload the config to regenerate sitemap
      load Rails.root.join("config", "sitemap.rb")
    rescue => e
      Rails.logger.error "Failed to regenerate sitemap: #{e.message}"
      # Don't raise - we don't want sitemap generation failures to break book operations
    end
  end
end
