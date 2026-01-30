class GroupItemAvailability < ApplicationRecord
  self.table_name = "group_item_availabilities"

  belongs_to :item
  belongs_to :community_group

  validates :community_group_id, uniqueness: { scope: :item_id, message: "is already linked to this item" }

  # Ransack allowlist for ActiveAdmin search/filter
  def self.ransackable_attributes(auth_object = nil)
    %w[
      id id_value item_id community_group_id created_at updated_at
    ]
  end

  def self.ransackable_associations(auth_object = nil)
    [ "item", "community_group" ]
  end
end

# Backward compatibility alias
GroupBookAvailability = GroupItemAvailability
