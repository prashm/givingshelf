# app/mailers/message_mailer.rb
class MessageMailer < ApplicationMailer
  def new_message_notification(message, recipient)
    @message = message
    @book_request = message.book_request
    @book = @book_request.book
    @sender = message.user
    @recipient = recipient
    
    mail(
      to: @recipient.email_address,
      subject: "New message about your book request: #{@book.title}"
    )
  end
end

