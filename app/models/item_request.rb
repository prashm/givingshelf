class ItemRequest < ApplicationRecord
  self.table_name = "item_requests"
  # The request message now lives in the thread as the initial PENDING event (GS-9). The column is
  # dropped in a later deploy; ignore it now so this code never reads or writes it.
  self.ignored_columns += [ "message" ]

  enum :status, {
    pending: 0,
    accepted: 1,
    declined: 2,
    in_review: 3,
    completed: 4,
    cancelled: 5
  }, validate: true

  # Requests still waiting for the owner's decision.
  OPEN_STATUSES = %w[pending in_review].freeze

  # Allowed status moves. DECLINED and COMPLETED are final; a CANCELLED request can only be
  # reopened (uncancel), and ItemRequestService also checks the item can still be given to it.
  TRANSITIONS = {
    "pending" => %w[in_review accepted declined cancelled],
    "in_review" => %w[accepted declined cancelled],
    "accepted" => %w[completed declined cancelled],
    "cancelled" => %w[pending],
    "declined" => [],
    "completed" => []
  }.freeze

  TRANSITION_VERBS = {
    "in_review" => "review",
    "accepted" => "accept",
    "declined" => "decline",
    "completed" => "complete",
    "cancelled" => "cancel",
    "pending" => "uncancel"
  }.freeze

  # Statuses where the requester is still waiting on a wishlist item.
  ACTIVE_WISH_STATUSES = %w[pending in_review].freeze

  belongs_to :requester, class_name: "User"
  # Loads the item even when its owner deleted it, so the request and its thread still work.
  belongs_to :item, -> { with_deleted }
  belongs_to :owner, class_name: "User", optional: true
  has_many :messages, dependent: :destroy

  alias_method :book, :item

  # The request message (the initial event's note); checked where requests are created.
  INITIAL_MESSAGE_LENGTH = (10..500).freeze
  validates :requester_id, uniqueness: { scope: :item_id, message: "has already requested this item" }
  validate :requester_cannot_request_own_item
  validate :item_must_be_available, on: :create

  scope :awaiting_decision, -> { where(status: OPEN_STATUSES) }
  scope :active_wish, -> { where(status: ACTIVE_WISH_STATUSES) }
  scope :for_user, ->(user) { where(requester: user) }
  scope :for_item_owner, ->(user) { where(owner: user) }
  scope :recent, -> { order(created_at: :desc) }

  # Lets ActiveAdmin filter by status name; the enum type maps it to the stored value.
  ransacker :status, type: :string do |parent|
    parent.table[:status]
  end

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

  # Display label for a status name, e.g. "In Review". Unknown statuses read as Pending.
  def self.status_label(status)
    status = status.to_s
    (statuses.key?(status) ? status : "pending").titleize
  end

  # [label, name] pairs for select inputs.
  def self.status_options
    statuses.keys.map { |name| [ status_label(name), name ] }
  end

  def status_label
    self.class.status_label(status)
  end

  # Whether the owner may still accept/decline/complete this request. Finished requests are locked.
  def can_update_status?
    return false if cancelled? || declined? || completed?
    accepted? || !other_requests.accepted.exists?
  end

  # The request's first PENDING event, whose content is the message the requester sent with it.
  # Memoized: the first event never changes once written.
  def initial_message
    return @initial_message if defined?(@initial_message)
    @initial_message = messages.transitions.where(request_transition_status: :pending).order(:created_at, :id).first
  end

  def reload(*)
    remove_instance_variable(:@initial_message) if defined?(@initial_message)
    super
  end

  # Whether either party can still add messages. A finished or cancelled request is read-only, and
  # so is a request with no owner yet (an open wish), since there's nobody to message.
  def message_thread_writable?
    owner_id.present? && !(cancelled? || declined? || completed?)
  end

  # The other requests for the same item.
  def other_requests
    item.item_requests.where.not(id: id)
  end

  def can_transition_to?(new_status)
    TRANSITIONS.fetch(status, []).include?(new_status.to_s)
  end

  # Raises unless the move from the current status to new_status is allowed.
  def guard_transition!(new_status)
    return if can_transition_to?(new_status)
    label = status_label.downcase
    article = label.match?(/\A[aeiou]/) ? "an" : "a"
    raise "Cannot #{TRANSITION_VERBS.fetch(new_status.to_s)} #{article} #{label} request"
  end

  private

  def set_default_status
    self.status ||= :pending
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
end
