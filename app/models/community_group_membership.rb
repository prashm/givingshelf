class CommunityGroupMembership < ApplicationRecord
  belongs_to :user
  belongs_to :community_group
  belongs_to :group_membership_request, optional: true
  belongs_to :sub_group, optional: true

  validates :user_id, uniqueness: { scope: :community_group_id, message: "is already a member of this group" }
  validate :sub_group_belongs_to_community_group

  scope :admins, -> { where(admin: true) }

  # Ransack allowlist for ActiveAdmin search/filter
  def self.ransackable_attributes(auth_object = nil)
    %w[
      id id_value user_id community_group_id admin auto_joined sub_group_id
      group_membership_request_id created_at updated_at
    ]
  end

  def self.ransackable_associations(auth_object = nil)
    ["community_group", "group_membership_request", "sub_group", "user"]
  end

  def sole_admin?
    return false unless user
    admin? && community_group.has_only_one_admin?
  end

  private

  def sub_group_belongs_to_community_group
    return if sub_group_id.blank?
    return if community_group_id.blank?

    return if sub_group&.community_group_id == community_group_id

    errors.add(:sub_group_id, "must belong to the same community group")
  end
end
