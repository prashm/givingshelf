# frozen_string_literal: true

class UserNotification < ApplicationRecord
  KIND_WISHLIST_DIGEST = "wishlist_digest"
  KIND_WISHLIST_AVAILABLE = "wishlist_available"

  belongs_to :user
  belongs_to :notifiable, polymorphic: true
end
