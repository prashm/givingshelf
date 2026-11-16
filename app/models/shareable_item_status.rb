class ShareableItemStatus < ActiveHash::Base
  self.data = [
    { value: "available", label: "Available" },
    { value: "requested", label: "Requested" },
    { value: "donated", label: "Donated" },
    { value: "wishlist", label: "Wishlist" }
  ]

  def self.display_status(status)
    self.all.find_by(value: status.to_s)&.label || "Unknown"
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
