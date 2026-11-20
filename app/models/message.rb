class Message < ApplicationRecord
  belongs_to :item_request
  belongs_to :user

  # A plain chat message needs text. A transition event (request_transition_status set) records a
  # status change, and its content is an optional note.
  validates :content, presence: true, unless: :transition?
  validates :content, length: { maximum: 1000 }
  validates :request_transition_status, inclusion: { in: ItemRequest::STATUS_LABELS.keys }, allow_nil: true

  scope :recent, -> { order(created_at: :desc) }
  scope :transitions, -> { where.not(request_transition_status: nil) }

  def transition?
    !request_transition_status.nil?
  end

  # Ransack allowlist for ActiveAdmin search/filter
  def self.ransackable_attributes(auth_object = nil)
    %w[
      id id_value item_request_id user_id content read_at request_transition_status
      created_at updated_at
    ]
  end

  def self.ransackable_associations(auth_object = nil)
    [ "item_request", "user" ]
  end
end
