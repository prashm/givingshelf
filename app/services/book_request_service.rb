# app/services/book_request_service.rb
class BookRequestService
    attr_accessor :book_request
    attr_reader :errors

  def initialize(book_request = nil)
    @book_request = book_request
    @errors = []
  end

  def create_request(requester, book_id, message)
    book = Book.find(book_id)

    unless requester.profile_complete?
      raise "User profile is incomplete."
    end

    book_service = BookService.new(book)
    unless book_service.book_can_be_requested_by?(requester)
      reason = "Cannot request this book"
      if book_service.book_cannot_be_requested_by_reason.present?
        reason = "#{reason}: #{book_service.book_cannot_be_requested_by_reason}"
      end
      raise reason
    end

    @book_request = requester.book_requests.build(book: book, message: message)

    if @book_request.save
      notify_book_owner
    else
      @errors += @book_request.errors.full_messages
      @book_request = nil
    end
    @book_request
  rescue => e
    @errors << e.message
    @book_request = nil
  end

  def update_request(current_user, action_type)
    # Only the book owner can update the request status
    raise "Not authorized" unless self.book_request.book.owner?(current_user)

    case action_type
    when "accept"
      self.book_request.accept!
    when "decline"
      self.book_request.decline!
    when "complete"
      self.book_request.complete!
    when "mark_as_viewed"
      self.book_request.mark_as_in_review!
    else
      raise "Invalid action"
    end
    true
  rescue => e
    @errors << e.message
    false
  end

  def cancel_request(requester)
    # Only the requester can cancel their own request
    if self.book_request.requester != requester
      raise "Not authorized"
    end

    self.book_request.destroy
    true
  rescue => e
    @errors << e.message
    false
  end

  def requests_for_user(user, type)
    book_requests = []
    case type
    when "received"
      # Requests received for user's books
      book_requests = BookRequest.for_book_owner(user)
        .includes(:book, :requester)
        .order(created_at: :desc)
    when "sent"
      # Requests sent by user
      book_requests = user.book_requests
        .includes(:book)
        .order(created_at: :desc)
    end
    book_requests
  end

  def request_json(request)
    {
      id: request.id,
      status: request.status,
      status_display: display_status(request.status),
      message: request.message,
      created_at: request.created_at,
      updated_at: request.updated_at,
      book: BookService.new.book_json(request.book),
      can_update_status: request.can_update_status?,
      requester: {
        id: request.requester.id,
        name: request.requester.display_name,
        location: request.requester.location,
        verified: request.requester.verified?
      }
    }
  end

  def display_status(status)
    case status
    when BookRequest::COMPLETED_STATUS
      "Completed"
    when BookRequest::ACCEPTED_STATUS
      "Accepted"
    when BookRequest::DECLINED_STATUS
      "Declined"
    when BookRequest::IN_REVIEW_STATUS
      "In Review"
    else
      "Pending"
    end
  end

  private

  def notify_book_owner
    BookRequestNotificationJob.perform_later(self.book_request)
  end
end
