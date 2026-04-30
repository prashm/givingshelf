class ShareableItemStatus < ActiveHash::Base
  # Status constants
  AVAILABLE = 0
  REQUESTED = 1
  DONATED = 2
  WISHLIST = 3

  self.data = [
    { value: AVAILABLE, label: "Available" },
    { value: REQUESTED, label: "Requested" },
    { value: DONATED, label: "Donated" },
    { value: WISHLIST, label: "Wishlist" }
  ]

  def self.display_status(status)
    self.all.find_by(value: status)&.label || "Unknown"
  end

  def self.collection
    h = {}
    self.all.each { |s| h[s.label] = s.value }
    h
  end

  def self.values
    self.all.map { |s| s.value }
  end
end

# Backward compatibility alias
BookStatus = ShareableItemStatus
