class BookRequest < ApplicationRecord
  # Status constants
  PENDING_STATUS = 0
  ACCEPTED_STATUS = 1
  DECLINED_STATUS = 2
  IN_REVIEW_STATUS = 3
  COMPLETED_STATUS = 4

  belongs_to :requester, class_name: "User"
  belongs_to :book
  belongs_to :owner, class_name: "User"
  has_many :messages, dependent: :destroy

  validates :message, presence: true, length: { minimum: 10, maximum: 500 }
  validates :status, inclusion: { in: [ PENDING_STATUS, ACCEPTED_STATUS, DECLINED_STATUS, IN_REVIEW_STATUS, COMPLETED_STATUS ], default: PENDING_STATUS }
  validates :requester_id, uniqueness: { scope: :book_id, message: "has already requested this book" }
  validate :requester_cannot_request_own_book
  validate :book_must_be_available, on: :create

  scope :pending, -> { where(status: PENDING_STATUS) }
  scope :accepted, -> { where(status: ACCEPTED_STATUS) }
  scope :completed, -> { where(status: COMPLETED_STATUS) }
  scope :in_review, -> { where(status: IN_REVIEW_STATUS) }
  scope :for_user, ->(user) { where(requester: user) }
  scope :for_book_owner, ->(user) { where(owner: user) }

  before_validation :set_owner, on: :create

  after_update :notify_status_change

  def accept!
    update!(status: ACCEPTED_STATUS)
    book.update!(status: Book::REQUESTED_STATUS)
    # Mark all other requests for this book as In Review
    book.book_requests.where.not(id: id).update_all(status: IN_REVIEW_STATUS)
  end

  def decline!
    update!(status: DECLINED_STATUS)
  end

  def complete!
    raise "Can only complete an accepted request" unless accepted?
    update!(status: COMPLETED_STATUS)
    book.update!(status: Book::DONATED_STATUS)
  end

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

  def can_update_status?
    status == ACCEPTED_STATUS || !book.book_requests.exists?(status: ACCEPTED_STATUS)
  end

  def mark_as_in_review!
    update!(status: IN_REVIEW_STATUS) if pending?
  end

  private

  def set_owner
    self.owner ||= book.user if book.present?
  end


  def requester_cannot_request_own_book
    if requester == book.user
      errors.add(:base, "You cannot request your own book")
    end
  end

  def book_must_be_available
    unless book.available?
      errors.add(:base, "This book is not available for request")
    end
  end


  def notify_status_change
    # In a real app, you'd send an email notification here
    Rails.logger.info "Status change notification sent to #{requester.email_address}"
  end
end
