class SupportItemType < ActiveHash::Base
  BOOKS_AND_TOYS = nil
  BOOKS_ONLY = "B"
  TOYS_ONLY = "T"

  self.data = [
    { value: BOOKS_AND_TOYS, label: "Books and Toys" },
    { value: BOOKS_ONLY, label: "Books Only" },
    { value: TOYS_ONLY, label: "Toys Only" }
  ]

  def self.label_for(value)
    self.all.find_by(value: value)&.label || "Unknown"
  end

  def self.values
    self.all.map { |s| s.value }.compact
  end

  def self.collection_for_select
    self.all.map { |s| [ s.label, s.value ] }
  end

  def self.item_class_for(value)
    case value
    when BOOKS_ONLY then Book.name
    when TOYS_ONLY then Toy.name
    else nil
    end
  end
end
