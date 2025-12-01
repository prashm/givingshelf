class Message < ApplicationRecord
  belongs_to :book_request
  belongs_to :user

  validates :content, presence: true, length: { minimum: 1, maximum: 1000 }

  scope :recent, -> { order(created_at: :desc) }
end
