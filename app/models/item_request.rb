class ItemRequest < ApplicationRecord
  self.table_name = "item_requests"
  # The request message now lives in the thread as the initial PENDING event (GS-9). The column is
  # dropped in a later deploy; ignore it now so this code never reads or writes it.
  self.ignored_columns += [ "message" ]

  # Status constants
  PENDING_STATUS = 0
  ACCEPTED_STATUS = 1
  DECLINED_STATUS = 2
  IN_REVIEW_STATUS = 3
  COMPLETED_STATUS = 4
  CANCELLED_STATUS = 5

  # Requests still waiting for the owner's decision.
  OPEN_STATUSES = [ PENDING_STATUS, IN_REVIEW_STATUS ].freeze

  STATUS_LABELS = {
    PENDING_STATUS => "Pending",
    ACCEPTED_STATUS => "Accepted",
    DECLINED_STATUS => "Declined",
    IN_REVIEW_STATUS => "In Review",
    COMPLETED_STATUS => "Completed",
    CANCELLED_STATUS => "Cancelled"
  }.freeze

  # Allowed status moves. DECLINED and COMPLETED are final; a CANCELLED request can only be
  # reopened (uncancel), and ItemRequestService also checks the item can still be given to it.
  TRANSITIONS = {
    PENDING_STATUS => [ IN_REVIEW_STATUS, ACCEPTED_STATUS, DECLINED_STATUS, CANCELLED_STATUS ],
    IN_REVIEW_STATUS => [ ACCEPTED_STATUS, DECLINED_STATUS, CANCELLED_STATUS ],
    ACCEPTED_STATUS => [ COMPLETED_STATUS, DECLINED_STATUS, CANCELLED_STATUS ],
    CANCELLED_STATUS => [ PENDING_STATUS ],
    DECLINED_STATUS => [],
    COMPLETED_STATUS => []
  }.freeze

  TRANSITION_VERBS = {
    IN_REVIEW_STATUS => "review",
    ACCEPTED_STATUS => "accept",
    DECLINED_STATUS => "decline",
    COMPLETED_STATUS => "complete",
    CANCELLED_STATUS => "cancel",
    PENDING_STATUS => "uncancel"
  }.freeze

  # Statuses where the requester is still waiting on a wishlist item.
  ACTIVE_WISH_STATUSES = [ PENDING_STATUS, IN_REVIEW_STATUS ].freeze

  belongs_to :requester, class_name: "User"
  belongs_to :item
  belongs_to :owner, class_name: "User", optional: true
  has_many :messages, dependent: :destroy

  alias_method :book, :item

  # The request message (the initial event's note); checked where requests are created.
  INITIAL_MESSAGE_LENGTH = (10..500).freeze
  validates :status, inclusion: { in: [ PENDING_STATUS, ACCEPTED_STATUS, DECLINED_STATUS, IN_REVIEW_STATUS, COMPLETED_STATUS, CANCELLED_STATUS ] }
  validates :requester_id, uniqueness: { scope: :item_id, message: "has already requested this item" }
  validate :requester_cannot_request_own_item
  validate :item_must_be_available, on: :create

  scope :pending, -> { where(status: PENDING_STATUS) }
  scope :accepted, -> { where(status: ACCEPTED_STATUS) }
  scope :completed, -> { where(status: COMPLETED_STATUS) }
  scope :in_review, -> { where(status: IN_REVIEW_STATUS) }
  scope :cancelled, -> { where(status: CANCELLED_STATUS) }
  scope :awaiting_decision, -> { where(status: OPEN_STATUSES) }
  scope :active_wish, -> { where(status: ACTIVE_WISH_STATUSES) }
  scope :for_user, ->(user) { where(requester: user) }
  scope :for_item_owner, ->(user) { where(owner: user) }
  scope :recent, -> { order(created_at: :desc) }

  # Ransack allowlist for ActiveAdmin search/filter
  def self.ransackable_attributes(auth_object = nil)
    %w[
      id id_value requester_id item_id owner_id status
      created_at updated_at
    ]
  end

  def self.ransackable_associations(auth_object = nil)
    [ "item", "owner", "requester", "messages" ]
  end

  before_validation :set_default_status, on: :create
  before_validation :set_owner, on: :create

  after_update :notify_status_change

  def pending?
    status == PENDING_STATUS
  end

  def accepted?
    status == ACCEPTED_STATUS
  end

  def declined?
    status == DECLINED_STATUS
  end

  def in_review?
    status == IN_REVIEW_STATUS
  end

  def completed?
    status == COMPLETED_STATUS
  end

  def cancelled?
    status == CANCELLED_STATUS
  end

  def self.status_label(status)
    STATUS_LABELS.fetch(status, STATUS_LABELS[PENDING_STATUS])
  end

  # Whether the owner may still accept/decline/complete this request. Finished requests are locked.
  def can_update_status?
    return false if cancelled? || declined? || completed?
    accepted? || !other_requests.accepted.exists?
  end

  # The message the requester sent with the request: the note on its first PENDING event.
  def initial_message
    messages.transitions.where(request_transition_status: PENDING_STATUS).order(:created_at, :id).first&.content
  end

  # Whether either party can still add messages. A finished or cancelled request is read-only, and
  # so is a request with no owner yet (an open wish), since there's nobody to message.
  def thread_writable?
    owner_id.present? && !(cancelled? || declined? || completed?)
  end

  # The other requests for the same item.
  def other_requests
    item.item_requests.where.not(id: id)
  end

  def can_transition_to?(new_status)
    TRANSITIONS.fetch(status, []).include?(new_status)
  end

  # Raises unless the move from the current status to new_status is allowed.
  def guard_transition!(new_status)
    return if can_transition_to?(new_status)
    label = self.class.status_label(status).downcase
    article = label.match?(/\A[aeiou]/) ? "an" : "a"
    raise "Cannot #{TRANSITION_VERBS.fetch(new_status)} #{article} #{label} request"
  end

  private

  def set_default_status
    self.status ||= PENDING_STATUS
  end

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
    errors.add(:base, "This item is not available for request") unless item.open_to_requests?
  end

  def notify_status_change
    # In a real app, you'd send an email notification here
    Rails.logger.info "Status change notification sent to #{requester.email_address}"
  end
end
