class Item < ApplicationRecord
  self.table_name = "items"


  belongs_to :user
  has_many :item_requests, dependent: :destroy
  has_many :group_item_availabilities, dependent: :destroy
  has_many :available_community_groups, through: :group_item_availabilities, source: :community_group
  has_one_attached :cover_image
  has_many_attached :user_images

  # Shared validations
  validates :title, presence: true, length: { minimum: 1, maximum: 255 }
  validates :condition, presence: true, inclusion: { in: %w[excellent good fair poor], message: "must be excellent, good, fair, or poor" }
  validates :summary, presence: true, length: { minimum: 10, maximum: 1000 }
  validates :status, inclusion: { in: ShareableItemStatus.values, default: ShareableItemStatus::AVAILABLE }

  # Shared scopes
  scope :available, -> { where.not(status: ShareableItemStatus::DONATED) }
  scope :by_condition, ->(condition) { where(condition: condition) }
  scope :recent, -> { order(created_at: :desc) }
  scope :nearby, ->(zip_code) { joins(:user).where(users: { zip_code: zip_code }) }

  # Ransack allowlist for ActiveAdmin search/filter
  def self.ransackable_attributes(auth_object = nil)
    %w[
      id id_value title condition summary status view_count
      personal_note pickup_method pickup_address
      user_id created_at updated_at type
    ]
  end

  def self.ransackable_associations(auth_object = nil)
    [ "item_requests", "user", "user_images" ]
  end

  def self.valid_type?(type)
    [ Book.name, Toy.name ].include?(type)
  end

  def cover_image_url
    cover_image.attached? ? cover_image : nil
  end

  def distance_from(zip_code)
    return 0 if user.zip_code == zip_code
    # Simple distance calculation - in a real app, you'd use a geocoding service
    zip_code.to_s[0..1] == user.zip_code[0..1] ? 1 : 2
  end

  def available?
    status == ShareableItemStatus::AVAILABLE
  end

  def requested?
    status == ShareableItemStatus::REQUESTED
  end

  def donated?
    status == ShareableItemStatus::DONATED
  end

  def owner?(current_user)
    current_user.present? && user == current_user
  end

  # Regenerate sitemap when items are created or updated
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
      # Don't raise - we don't want sitemap generation failures to break item operations
    end
  end
end
