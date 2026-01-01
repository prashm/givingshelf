class CommunityGroupMembership < ApplicationRecord
  belongs_to :user
  belongs_to :community_group

  validates :user_id, uniqueness: { scope: :community_group_id, message: "is already a member of this group" }

  scope :admins, -> { where(admin: true) }
end

