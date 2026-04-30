# frozen_string_literal: true

class WishlistDigestJob < ApplicationJob
  queue_as :default

  def perform
    wishlist_books = Book.wishlist.includes(:item_requests, :group_item_availabilities, item_requests: :requester)
    by_recipient = Hash.new { |h, k| h[k] = [] }

    wishlist_books.find_each do |book|
      book.item_requests.where(status: ItemRequest::PENDING_STATUS).find_each do |ir|
        next unless ir.requester
        scoped_availabilities = book.group_item_availabilities
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
            notifiable: book,
            kind: UserNotification::KIND_WISHLIST_DIGEST
          )
          by_recipient[u] << { item: book, requester: ir.requester }
        end
      end
    end

    by_recipient.each do |user, rows|
      rows.uniq! { |r| r[:item].id }
      next if rows.empty?

      WishlistMailer.digest(user, rows).deliver_later
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
  end
end
