class ItemRequest < ApplicationRecord
  self.table_name = "item_requests"

  enum :status, {
    pending: 0,
    accepted: 1,
    declined: 2,
    in_review: 3,
    completed: 4,
    cancelled: 5
  }, default: :pending, validate: true

  belongs_to :requester, class_name: "User"
  belongs_to :item
  belongs_to :owner, class_name: "User", optional: true
  has_many :messages, dependent: :destroy

  alias_method :book, :item

  validates :message, presence: true, length: { minimum: 10, maximum: 500 }
  validates :requester_id, uniqueness: { scope: :item_id, message: "has already requested this item" }
  validate :requester_cannot_request_own_item
  validate :item_must_be_available, on: :create

  scope :for_user, ->(user) { where(requester: user) }
  scope :for_item_owner, ->(user) { where(owner: user) }
  scope :recent, -> { order(created_at: :desc) }

  # Ransack allowlist for ActiveAdmin search/filter
  def self.ransackable_attributes(auth_object = nil)
    %w[
      id id_value requester_id item_id owner_id status message
      created_at updated_at
    ]
  end

  def self.ransackable_associations(auth_object = nil)
    [ "item", "owner", "requester", "messages" ]
  end

  before_validation :set_owner, on: :create

  after_update :notify_status_change

  def can_update_status?
    return false if cancelled?
    accepted? || !item.item_requests.accepted.exists?
  end

  private

  def set_owner
    return unless item.present?
    self.owner ||= item.user if item.user.present?
  end

  def requester_cannot_request_own_item
    return if item.user.nil?
    if requester == item.user
      errors.add(:base, "You cannot request your own item")
    end
  end

  def item_must_be_available
    if item.wishlist?
      return
    end
    unless item.available?
      errors.add(:base, "This item is not available for request")
    end
  end

  def notify_status_change
    # In a real app, you'd send an email notification here
    Rails.logger.info "Status change notification sent to #{requester.email_address}"
  end
end
