class CommunityGroup < ApplicationRecord
  ZIPCODE_SHORT_NAME = "zipcode".freeze
  ZIPCODE_GROUP_NAME = "ZIP Code Community".freeze
  ZIPCODE_GROUP_DESCRIPTION = "Discover and Share Books Within Your ZIP Code".freeze
  DEFAULT_SHORT_DESCRIPTION = "Discover and Share Books Within This Group".freeze
  GROUP_ADMINS_SHORT_NAME = "group-admins".freeze

  has_many :sub_groups, dependent: :destroy
  has_many :community_group_memberships, dependent: :destroy
  has_many :members, through: :community_group_memberships, source: :user
  has_many :admins, -> { where(community_group_memberships: { admin: true }) }, through: :community_group_memberships, source: :user
  has_many :group_item_availabilities, dependent: :destroy
  has_many :available_items, through: :group_item_availabilities, source: :item
  has_many :available_books, -> { where(type: "Book") }, through: :group_item_availabilities, source: :item
  has_many :available_toys, -> { where(type: "Toy") }, through: :group_item_availabilities, source: :item
  # Backward compatibility alias
  has_many :group_book_availabilities, class_name: "GroupItemAvailability", foreign_key: "community_group_id", dependent: :destroy

  has_one_attached :logo

  before_validation :set_default_short_description
  before_validation :normalize_blank_domain

  validates :name, presence: true
  validates :domain, uniqueness: true, allow_blank: true,
                     format: { with: /\A[\w\.-]+\.[a-z]{2,}\z/i, message: "must be a valid domain" }
  validates :short_name, presence: true, uniqueness: true, format: { with: /\A[a-z0-9-]+\z/, message: "must be lowercase alphanumeric and hyphens only" }
  validates :group_description, length: { maximum: 100 }, allow_blank: true

  scope :by_domain, ->(domain) { where(domain: domain) }
  scope :by_short_name, ->(short_name) { where(short_name: short_name) }

  # Ransack allowlist for ActiveAdmin search/filter
  def self.ransackable_attributes(auth_object = nil)
    %w[
      id id_value name short_name domain group_description public
      created_at updated_at
    ]
  end

  def self.ransackable_associations(auth_object = nil)
    [ "sub_groups", "community_group_memberships", "members", "admins", "group_book_availabilities", "available_books" ]
  end

  def self.find_or_create_zipcode_group!
    find_or_create_by!(short_name: ZIPCODE_SHORT_NAME) do |g|
      g.name = ZIPCODE_GROUP_NAME
      g.group_description = ZIPCODE_GROUP_DESCRIPTION
    end
  end

  def self.admin?(user)
    return false unless user
    group = find_by(short_name: GROUP_ADMINS_SHORT_NAME)
    return false unless group
    group.community_group_memberships.exists?(user: user)
  end

  def admin?(user)
    return false unless user
    community_group_memberships.exists?(user: user, admin: true)
  end

  def has_only_one_admin?
    community_group_memberships.admins.count == 1
  end

  def self.zipcode_group
    find_by(short_name: ZIPCODE_SHORT_NAME)
  end

  def logo_url
    logo.attachment.url if logo.attached?
  end

  private

  def set_default_short_description
    self.group_description = DEFAULT_SHORT_DESCRIPTION if group_description.blank?
  end

  def normalize_blank_domain
    self.domain = nil if domain.blank?
  end
end
