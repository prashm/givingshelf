# app/mailers/message_mailer.rb
class MessageMailer < ApplicationMailer
  def new_message_notification(message, recipient)
    @message = message
    @item_request = message.item_request
    @item = @item_request.item
    @sender = message.user
    @recipient = recipient

    item_type = @item.type.downcase
    mail(
      to: @recipient.email_address,
      subject: "New message about your #{item_type} request: #{@item.title}"
    )
  end
end
