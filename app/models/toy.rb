class Toy < Item
  # Toy-specific validations (brand and age_range optional)
  validates :brand, length: { maximum: 255 }, allow_blank: true

  before_validation :parse_age_range, if: -> { will_save_change_to_age_range? }

  # Toy-specific scopes
  scope :by_brand, ->(brand) { where("brand ILIKE ?", "%#{brand}%") }

  # Associations (same as Book)
  has_many :item_requests, foreign_key: "item_id", dependent: :destroy
  has_many :group_item_availabilities, foreign_key: "item_id", dependent: :destroy
  has_many :available_community_groups, through: :group_item_availabilities, source: :community_group

  # Ransack allowlist for ActiveAdmin search/filter
  def self.ransackable_attributes(auth_object = nil)
    %w[
      id id_value title brand age_range min_age max_age condition summary status view_count
      personal_note pickup_method pickup_address
      user_id created_at updated_at
    ]
  end

  def self.ransackable_associations(auth_object = nil)
    [ "item_requests", "user", "user_images" ]
  end

  private

  def parse_age_range(*)
    if age_range.blank?
      self.age_range = nil
      self.min_age = nil
      self.max_age = nil
      return
    end

    parsed = ToyAgeRange.parse(age_range)
    if parsed
      self.age_range = parsed[:label]
      self.min_age = parsed[:min]
      self.max_age = parsed[:max]
    else
      errors.add(:age_range, "is not recognized")
    end
  end
end
