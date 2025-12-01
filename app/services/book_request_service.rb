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
    
    unless book.can_be_requested_by?(requester)
      raise "Cannot request this book"
    end

    p @book_request = requester.book_requests.build(book: book, message: message)
    
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
    when 'accept'
      self.book_request.accept!
    when 'decline'
      self.book_request.decline!
    when 'complete'
      self.book_request.complete!
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
    when 'received'
      # Requests received for user's books
      book_requests = BookRequest.for_book_owner(user)
        .includes(:book, :requester)
        .order(created_at: :desc)
    when 'sent'
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
      message: request.message,
      created_at: request.created_at,
      updated_at: request.updated_at,
      book: BookService.new.book_json(request.book),
      requester: {
        id: request.requester.id,
        name: request.requester.display_name,
        location: request.requester.location,
        verified: request.requester.verified?
      }
    }
  end
  
  private

  def notify_book_owner
    BookRequestNotificationJob.perform_later(self.book_request)
  end
end