class CommunityGroupMembership < ApplicationRecord
  belongs_to :user
  belongs_to :community_group
  belongs_to :group_membership_request, optional: true
  belongs_to :sub_group, optional: true

  validates :user_id, uniqueness: { scope: :community_group_id, message: "is already a member of this group" }
  validate :sub_group_belongs_to_community_group

  scope :admins, -> { where(admin: true) }

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
