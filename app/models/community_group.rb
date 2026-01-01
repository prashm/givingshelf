class CommunityGroup < ApplicationRecord
  has_many :sub_groups, dependent: :destroy
  has_many :community_group_memberships, dependent: :destroy
  has_many :members, through: :community_group_memberships, source: :user
  has_many :admins, -> { where(community_group_memberships: { admin: true }) }, through: :community_group_memberships, source: :user

  validates :name, presence: true
  validates :domain, presence: true, uniqueness: true, format: { with: /\A[\w\.-]+\.[a-z]{2,}\z/i, message: "must be a valid domain" }
  validates :short_name, presence: true, uniqueness: true, format: { with: /\A[a-z0-9-]+\z/, message: "must be lowercase alphanumeric and hyphens only" }

  scope :by_domain, ->(domain) { where(domain: domain) }
  scope :by_short_name, ->(short_name) { where(short_name: short_name) }

  GROUP_ADMINS_SHORT_NAME = "group-admins"

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
end
