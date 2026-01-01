class SubGroup < ApplicationRecord
  belongs_to :community_group

  validates :name, presence: true
  validates :name, uniqueness: { scope: :community_group_id, message: "must be unique within the group" }
end

