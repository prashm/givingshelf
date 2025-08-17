class BookRequest < ApplicationRecord
  belongs_to :requester, class_name: 'User'
  belongs_to :book

  validates :message, presence: true, length: { minimum: 10, maximum: 500 }
  validates :status, inclusion: { in: %w[pending accepted declined completed], default: 'pending' }
  validate :requester_cannot_request_own_book
  validate :book_must_be_available, on: :create

  scope :pending, -> { where(status: 'pending') }
  scope :accepted, -> { where(status: 'accepted') }
  scope :completed, -> { where(status: 'completed') }
  scope :for_user, ->(user) { where(requester: user) }
  scope :for_book_owner, ->(user) { joins(:book).where(books: { user: user }) }

  after_create :notify_book_owner
  after_update :notify_status_change

  def accept!
    update!(status: 'accepted')
    book.update!(status: 'requested')
  end

  def decline!
    update!(status: 'declined')
  end

  def complete!
    update!(status: 'completed')
    book.update!(status: 'donated')
  end

  def pending?
    status == 'pending'
  end

  def accepted?
    status == 'accepted'
  end

  def declined?
    status == 'declined'
  end

  def completed?
    status == 'completed'
  end

  private

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

  def notify_book_owner
    # In a real app, you'd send an email notification here
    Rails.logger.info "Book request notification sent to #{book.user.email_address}"
  end

  def notify_status_change
    # In a real app, you'd send an email notification here
    Rails.logger.info "Status change notification sent to #{requester.email_address}"
  end
end
