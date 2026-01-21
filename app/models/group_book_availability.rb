class GroupBookAvailability < ApplicationRecord
  belongs_to :book
  belongs_to :community_group

  validates :community_group_id, uniqueness: { scope: :book_id, message: "is already linked to this book" }
end

