# frozen_string_literal: true

class WishlistMailer < ApplicationMailer
  def digest(user, wishlist_items_with_requesters)
    @user = user
    @entries = wishlist_items_with_requesters
    mail(to: @user.email_address, subject: "Community Wishlist — can you help?")
  end

  def wishlist_available(user, item, item_request)
    @user = user
    @item = item
    @item_request = item_request
    @action_url = "#{root_url}item_request_details?id=#{item_request.id}"
    mail(to: @user.email_address, subject: "Good news: someone offered a #{@item.type.downcase} from your wishlist")
  end
end
