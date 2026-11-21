# frozen_string_literal: true

class UserNotification < ApplicationRecord
  KIND_WISHLIST_DIGEST = "wishlist_digest"
  KIND_WISHLIST_AVAILABLE = "wishlist_available"
  # GS-11: one email per request status change (notifiable: the transition event Message)...
  KIND_REQUEST_EVENT = "request_event"
  # ...and the notices to an item's other open requesters (notifiable: the event that caused them).
  KIND_OTHER_CHOSEN = "other_chosen"
  KIND_AVAILABLE_AGAIN = "available_again"

  belongs_to :user
  belongs_to :notifiable, polymorphic: true
end
