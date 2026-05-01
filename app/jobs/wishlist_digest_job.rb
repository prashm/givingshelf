# frozen_string_literal: true

class WishlistDigestJob < ApplicationJob
  queue_as :default
  ADMIN_REPORT_EMAIL = "admin@givingshelf.net".freeze

  def perform
    run_at = Time.current
    wishlist_items = Item.wishlist.includes(:item_requests, :group_item_availabilities, item_requests: :requester)
    by_recipient = Hash.new { |h, k| h[k] = [] }
    delivery_failures = []
    recipient_count = 0
    success_count = 0
    failure_count = 0

    wishlist_items.find_each do |item|
      item.item_requests.where(status: ItemRequest::PENDING_STATUS).find_each do |ir|
        next unless ir.requester
        scoped_availabilities = item.group_item_availabilities
        next if scoped_availabilities.blank?
        member_ids = []

        scoped_availabilities.each do |availability|
          scope = CommunityGroupMembership
            .where(community_group_id: availability.community_group_id)
            .where.not(user_id: ir.requester_id)
          scope = scope.where(sub_group_id: availability.sub_group_id) if availability.sub_group_id.present?
          member_ids.concat(scope.pluck(:user_id))
        end

        member_ids.uniq.each do |uid|
          u = User.find_by(id: uid)
          next if u.nil?
          next if UserNotification.exists?(
            user: u,
            notifiable: item,
            kind: UserNotification::KIND_WISHLIST_DIGEST
          )
          by_recipient[u] << { item: item, requester: ir.requester }
        end
      end
    end

    by_recipient.each do |user, rows|
      rows.uniq! { |r| r[:item].id }
      next if rows.empty?
      recipient_count += 1

      begin
        WishlistMailer.digest(user, rows).deliver_now!
        success_count += 1
      rescue => e
        failure_count += 1
        delivery_failures << {
          user_id: user.id,
          user_email: user.email_address,
          item_ids: rows.map { |r| r[:item].id },
          error_class: e.class.name,
          error_message: e.message.to_s
        }
        Rails.logger.error(
          "[WishlistDigestJob] Failed to deliver digest to user_id=#{user.id} " \
          "email=#{user.email_address}: #{e.class} #{e.message}"
        )
        next
      end

      rows.each do |row|
        item = row[:item]
        next if UserNotification.exists?(user: user, notifiable: item, kind: UserNotification::KIND_WISHLIST_DIGEST)
        UserNotification.create!(
          user: user,
          notifiable: item,
          kind: UserNotification::KIND_WISHLIST_DIGEST,
          sent_at: Time.current
        )
      end
    end

    begin
      WishlistMailer.digest_admin_report(
        ADMIN_REPORT_EMAIL,
        run_at: run_at,
        recipient_count: recipient_count,
        success_count: success_count,
        failure_count: failure_count,
        failures: delivery_failures
      ).deliver_now!
    rescue => e
      Rails.logger.error(
        "[WishlistDigestJob] Failed to deliver admin report to #{ADMIN_REPORT_EMAIL}: " \
        "#{e.class} #{e.message}"
      )
    end
  end
end
