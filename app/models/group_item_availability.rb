class GroupItemAvailability < ApplicationRecord
  self.table_name = "group_item_availabilities"

  belongs_to :item
  belongs_to :community_group
  belongs_to :sub_group, optional: true

  validates :community_group_id, uniqueness: { scope: :item_id, message: "is already linked to this item" }
  validate :sub_group_belongs_to_community_group

  # Ransack allowlist for ActiveAdmin search/filter
  def self.ransackable_attributes(auth_object = nil)
    %w[
      id id_value item_id community_group_id sub_group_id created_at updated_at
    ]
  end

  def self.ransackable_associations(auth_object = nil)
    [ "item", "community_group", "sub_group" ]
  end

  private

  def sub_group_belongs_to_community_group
    return if sub_group.nil? || community_group_id.blank? || sub_group.community_group_id == community_group_id

    errors.add(:sub_group_id, "must belong to the same community group")
  end
end

# Backward compatibility alias
GroupBookAvailability = GroupItemAvailability
