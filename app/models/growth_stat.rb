class GrowthStat < ApplicationRecord
  belongs_to :community_group, optional: true

  validates :stat_type, :stat_name, :stat_value, :computed_at, presence: true

  scope :for_type, ->(type) { where(stat_type: type) }
  scope :global, -> { where(community_group_id: nil) }
  scope :for_community_group, ->(group) { where(community_group: group) }
end
