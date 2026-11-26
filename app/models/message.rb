class Message < ApplicationRecord
  belongs_to :item_request
  belongs_to :user

  # A plain chat message needs text. A transition event (request_transition_status set) records a
  # status change, and its content is an optional note.
  validates :content, presence: true, unless: :transition?
  validates :content, length: { maximum: 1000 }
  # Reads and writes an ItemRequest status by name ("accepted") and stores it with ItemRequest's
  # status enum mapping, so the two can't drift apart. An unknown name is kept as given, so the
  # inclusion validation below rejects it instead of it being saved as nil.
  class RequestStatusType < ActiveModel::Type::Value
    def type
      :integer
    end

    def deserialize(value)
      ItemRequest.statuses.key(value.to_i) unless value.nil?
    end

    def serialize(value)
      name = cast(value)
      ItemRequest.statuses.fetch(name, name)
    end

    private

    def cast_value(value)
      value.is_a?(Integer) ? ItemRequest.statuses.key(value) : value.to_s.presence
    end
  end

  attribute :request_transition_status, RequestStatusType.new
  validates :request_transition_status, inclusion: { in: ItemRequest.statuses.keys }, allow_nil: true

  scope :recent, -> { order(created_at: :desc) }
  scope :transitions, -> { where.not(request_transition_status: nil) }

  def transition?
    request_transition_status.present?
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
