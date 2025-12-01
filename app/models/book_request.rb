class BookRequest < ApplicationRecord
  belongs_to :requester, class_name: "User"
  belongs_to :book
  belongs_to :owner, class_name: "User"
  has_many :messages, dependent: :destroy

  validates :message, presence: true, length: { minimum: 10, maximum: 500 }
  validates :status, inclusion: { in: %w[pending accepted declined completed], default: "pending" }
  validates :requester_id, uniqueness: { scope: :book_id, message: "has already requested this book" }
  validate :requester_cannot_request_own_book
  validate :book_must_be_available, on: :create

  scope :pending, -> { where(status: "pending") }
  scope :accepted, -> { where(status: "accepted") }
  scope :completed, -> { where(status: "completed") }
  scope :for_user, ->(user) { where(requester: user) }
  scope :for_book_owner, ->(user) { where(owner: user) }

  before_validation :set_owner, :set_status, on: :create

  after_update :notify_status_change

  def accept!
    update!(status: "accepted")
    book.update!(status: "requested")
  end

  def decline!
    update!(status: "declined")
  end

  def complete!
    update!(status: "completed")
    book.update!(status: "donated")
  end

  def pending?
    status == "pending"
  end

  def accepted?
    status == "accepted"
  end

  def declined?
    status == "declined"
  end

  def completed?
    status == "completed"
  end

  private

  def set_owner
    self.owner ||= book.user if book.present?
  end

  def set_status
    self.status ||= "pending"
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
