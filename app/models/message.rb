class Message < ApplicationRecord
  belongs_to :item_request
  belongs_to :user

  validates :content, presence: true, length: { minimum: 1, maximum: 1000 }

  scope :recent, -> { order(created_at: :desc) }

  # Ransack allowlist for ActiveAdmin search/filter
  def self.ransackable_attributes(auth_object = nil)
    %w[
      id id_value item_request_id user_id content read_at
      created_at updated_at
    ]
  end

  def self.ransackable_associations(auth_object = nil)
    [ "item_request", "user" ]
  end
end
