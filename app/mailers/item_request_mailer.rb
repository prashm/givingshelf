# app/mailers/item_request_mailer.rb
class ItemRequestMailer < ApplicationMailer
  def new_request_notification(item_request)
    @item_request = item_request
    @item = item_request.item
    @requester = item_request.requester

    item_type = @item.type.downcase
    mail(
      to: @item.user.email_address,
      subject: "New #{item_type.capitalize} Request: #{@item.title}"
    )
  end
end
