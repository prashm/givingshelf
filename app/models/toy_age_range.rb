class ToyAgeRange < ActiveHash::Base
  # Upper bound used when a toy age is open-ended (e.g. "8+"): stored as max_age = nil,
  # but treated as this value when computing bucket overlap.
  OPEN_MAX = 999

  self.data = [
    { value: "0-2 years", label: "0-2 years", min: 0, max: 2 },
    { value: "3-4 years", label: "3-4 years", min: 3, max: 4 },
    { value: "5-7 years", label: "5-7 years", min: 5, max: 7 },
    { value: "8-10 years", label: "8-10 years", min: 8, max: 10 },
    { value: "11-12 years", label: "11-12 years", min: 11, max: 12 },
    { value: "13+ years", label: "13+ years", min: 13, max: nil }
  ]

  # Aliases the parser accepts in addition to numeric formats, surfaced to the
  # frontend as example inputs.
  EXAMPLE_INPUTS = [ "8+", "7+", "3-6 years", "5-7 years", "toddler", "preschool" ].freeze

  # Machine-readable patterns the frontend uses for best-effort blur validation.
  # Authoritative validation happens on save via .parse.
  INPUT_PATTERNS = [
    { label: "Ages N+", regex: "^\\d+\\s*\\+$" },
    { label: "Ages N-M", regex: "^\\d+\\s*-\\s*\\d+" }
  ].freeze

  def self.display_age_range(value)
    all.find_by(value: value)&.label || value
  end

  def self.values
    all.map(&:value)
  end

  def self.collection
    h = {}
    all.each { |r| h[r.label] = r.value }
    h
  end

  # Bounds for a canonical browse bucket value, e.g. "8-10 years" => { min: 8, max: 10 }.
  def self.bucket_bounds(value)
    bucket = all.find_by(value: value)
    return nil unless bucket

    { min: bucket.min, max: bucket.max }
  end

  # Canonical bucket values that overlap the given age bounds. A nil max is treated
  # as open-ended.
  def self.matching_buckets(min, max)
    return [] if min.nil?

    effective_max = max || OPEN_MAX
    all.select do |bucket|
      bucket_max = bucket.max || OPEN_MAX
      bucket.min <= effective_max && bucket_max >= min
    end.map(&:value)
  end

  # Metadata for the frontend: canonical bucket labels, example inputs, and
  # validation patterns.
  def self.accepted_inputs
    {
      bucket_labels: values,
      examples: EXAMPLE_INPUTS,
      patterns: INPUT_PATTERNS
    }
  end

  # Parse a free-text age label into numeric bounds. Returns
  # { min:, max:, label: } (label is the trimmed input) or nil when unrecognized.
  def self.parse(raw_value)
    return nil if raw_value.blank?

    label = raw_value.to_s.strip
    normalized = label.downcase.gsub(/\s+/, " ")

    bounds = bounds_from_bucket(normalized) ||
      bounds_from_alias(normalized) ||
      bounds_from_range(normalized) ||
      bounds_from_open_ended(normalized) ||
      bounds_from_single_age(normalized)

    return nil unless bounds

    { min: bounds[:min], max: bounds[:max], label: label }
  end

  def self.bounds_from_bucket(normalized)
    bucket = all.find { |b| b.value.downcase == normalized }
    return nil unless bucket

    { min: bucket.min, max: bucket.max }
  end
  private_class_method :bounds_from_bucket

  def self.bounds_from_alias(normalized)
    case normalized
    when /\A(birth|newborn|infant|baby|toddler)\b/
      { min: 0, max: 2 }
    when /\Apreschool\b/
      { min: 3, max: 4 }
    when /\Akindergarten\b/
      { min: 5, max: 7 }
    when /\Apreteen\b/
      { min: 11, max: 12 }
    when /\A(teen|adult)\b/
      { min: 13, max: nil }
    end
  end
  private_class_method :bounds_from_alias

  def self.bounds_from_range(normalized)
    return nil unless (m = normalized.match(/\A(\d+)\s*-\s*(\d+)/))

    low = m[1].to_i
    high = m[2].to_i
    return nil if high < low

    { min: low, max: high }
  end
  private_class_method :bounds_from_range

  def self.bounds_from_open_ended(normalized)
    return nil unless (m = normalized.match(/\A(\d+)\s*\+/))

    { min: m[1].to_i, max: nil }
  end
  private_class_method :bounds_from_open_ended

  def self.bounds_from_single_age(normalized)
    return nil unless (m = normalized.match(/\A(\d+)\s*(year|yr|yo|month|mo)?/))

    age = m[1].to_i
    unit = m[2]
    return { min: 0, max: 2 } if unit&.start_with?("mo")

    { min: age, max: age }
  end
  private_class_method :bounds_from_single_age
end
