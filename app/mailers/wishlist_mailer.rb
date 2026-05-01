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

  def digest_admin_report(admin_email, run_at:, recipient_count:, success_count:, failure_count:, failures: [])
    @run_at = run_at
    @recipient_count = recipient_count
    @success_count = success_count
    @failure_count = failure_count
    @failures = Array(failures)
    mail(
      to: admin_email,
      subject: "Wishlist Digest Report"
    )
  end
end
