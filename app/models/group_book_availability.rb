class GroupBookAvailability < ApplicationRecord
  belongs_to :book
  belongs_to :community_group

  validates :community_group_id, uniqueness: { scope: :book_id, message: "is already linked to this book" }

  # Ransack allowlist for ActiveAdmin search/filter
  def self.ransackable_attributes(auth_object = nil)
    %w[
      id id_value book_id community_group_id created_at updated_at
    ]
  end

  def self.ransackable_associations(auth_object = nil)
    ["book", "community_group"]
  end
end

