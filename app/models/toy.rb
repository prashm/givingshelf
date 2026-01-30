class Toy < Item
  # Toy-specific validations
  validates :brand, presence: true, length: { minimum: 1, maximum: 255 }
  validates :age_range, presence: true, length: { minimum: 1, maximum: 50 }

  # Toy-specific scopes
  scope :by_brand, ->(brand) { where("brand ILIKE ?", "%#{brand}%") }
  scope :by_age_range, ->(age_range) { where(age_range: age_range) }

  # Associations (same as Book)
  has_many :item_requests, foreign_key: "item_id", dependent: :destroy
  has_many :group_item_availabilities, foreign_key: "item_id", dependent: :destroy
  has_many :available_community_groups, through: :group_item_availabilities, source: :community_group

  # Ransack allowlist for ActiveAdmin search/filter
  def self.ransackable_attributes(auth_object = nil)
    %w[
      id id_value title brand age_range condition summary status view_count
      personal_note pickup_method pickup_address
      user_id created_at updated_at
    ]
  end

  def self.ransackable_associations(auth_object = nil)
    [ "item_requests", "user", "user_images" ]
  end
end
