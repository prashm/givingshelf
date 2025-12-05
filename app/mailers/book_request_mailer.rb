# app/mailers/book_request_mailer.rb
class BookRequestMailer < ApplicationMailer
    def new_request_notification(book_request)
      @book_request = book_request
      @book = book_request.book
      @requester = book_request.requester

      mail(
        to: @book.user.email_address,
        subject: "New Book Request: #{@book.title}"
      )
    end
end
