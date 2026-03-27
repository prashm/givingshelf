class LandingGrowthStats < ActiveHash::Base
  STAT_TYPE = "landing_growth"

  # Stat names
  LOCAL_GIVERS = "local_givers"
  ITEMS_SHARED = "items_shared"
  GROUPS_CREATED = "groups_created"

  self.data = [
    { name: LOCAL_GIVERS, display_label: "Local Givers", min_value: 100 },
    { name: ITEMS_SHARED, display_label: "Books & Toys Shared", min_value: 200 },
    { name: GROUPS_CREATED, display_label: "Local Groups Created", min_value: 25 }
  ]

  def self.display_name(name)
    self.all.find_by(name: name)&.display_label || "Unknown"
  end

  def self.min_value_for(name)
    self.all.find_by(name: name)&.min_value.to_i
  end

  def self.names
    self.all.map { |s| s.name }
  end
end
