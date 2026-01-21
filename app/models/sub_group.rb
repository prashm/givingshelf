class SubGroup < ApplicationRecord
  belongs_to :community_group

  validates :name, presence: true
  validates :name, uniqueness: { scope: :community_group_id, message: "must be unique within the group" }

  # Ransack allowlist for ActiveAdmin search/filter
  def self.ransackable_attributes(auth_object = nil)
    %w[
      id id_value name community_group_id created_at updated_at
    ]
  end

  def self.ransackable_associations(auth_object = nil)
    ["community_group"]
  end
end

