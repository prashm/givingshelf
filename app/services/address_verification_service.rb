require "net/http"
require "json"
require "uri"

class AddressVerificationService
  attr_reader :errors

  def initialize
    @errors = []
  end

  # Verify an address using Mapbox Geocoding API
  # Returns: { verified: boolean, normalized_address: hash, confidence: float }
  def verify(address_params, proximity_zip_or_ip = nil)
    address_params = address_params.with_indifferent_access
    street_address = address_params[:street_address]
    city = address_params[:city]
    state = address_params[:state]
    zip_code = address_params[:zip_code]

    raise "Address fields are required" if street_address.blank? || city.blank? || state.blank?

    # Build query string for Mapbox
    query = "#{street_address}, #{city}, #{state}"
    query += " #{zip_code}" if zip_code.present?

    # Get proximity coordinates if zip code is provided
    if proximity_zip_or_ip.present? && proximity_zip_or_ip.match?(/\A\d{5}(-\d{4})?\z/)
      # It's a zip code, geocode it first
      proximity = geocode_zip_code(proximity_zip_or_ip)
    end

    # Call Mapbox Geocoding API
    results = geocode_address(query, proximity: proximity, limit: 1)

    raise "No address found" if results.empty?

    result = results.first
    result[:relevance] >= 0.7
  rescue => e
    @errors << e.message
    false
  end

  def geocode_address(query, proximity: nil, limit: 5, types: "address")
    return [] unless Mapbox::ACCESS_TOKEN.present?

    url = Mapbox.geocoding_url(query, {
      limit: limit,
      types: types,
      country: "us" # Limit to US addresses
    })

    # Add proximity if available
    if proximity
      url += "&proximity=#{proximity[:longitude]},#{proximity[:latitude]}"
    end

    uri = URI(url)
    response = Net::HTTP.get_response(uri)

    unless response.is_a?(Net::HTTPSuccess)
      @errors << "Mapbox API error: #{response.code}"
      return []
    end

    data = JSON.parse(response.body)
    features = data["features"] || []

    features.map do |feature|
      context = extract_context(feature)
      {
        id: feature["id"],
        relevance: feature["relevance"],
        coordinates: feature["geometry"]["coordinates"], # [longitude, latitude]
        street_address: extract_street_address_from_feature(feature, context),
        city: extract_city_from_context(context),
        state: extract_state_from_context(context),
        zip_code: extract_zip_code_from_context(context),
        full_address: feature["place_name"]
      }
    end
  end

  def geocode_zip_code(zip_code)
    # TODO: Uncomment this to switch to Mapbox geocoding API
    # return nil unless Mapbox::ACCESS_TOKEN.present?

    # url = Mapbox.geocoding_url(zip_code, {
    #   limit: 1,
    #   types: "postcode",
    #   country: "us"
    # })

    # uri = URI(url)
    # response = Net::HTTP.get_response(uri)

    # return nil unless response.is_a?(Net::HTTPSuccess)

    # data = JSON.parse(response.body)
    # feature = data["features"]&.first
    # return nil unless feature

    # coords = feature["geometry"]["coordinates"]
    # { latitude: coords[1], longitude: coords[0] }

    return nil if zip_code.blank?

    begin
      results = Geocoder.search(zip_code)
      raise "No results found" if results.empty?
      # Get the last result since that matches US ZIP codes
      result = results.last
      { latitude: result.latitude, longitude: result.longitude }
    rescue => e
      @errors << "Geocoding error for ZIP code #{zip_code}: #{e.message}"
      nil
    end
  end

  private

  def extract_context(feature)
    feature["context"] || []
  end

  def extract_street_address_from_feature(feature, context)
    # Try to get street address from feature properties
    feature["properties"]["address"] || feature["text"] || ""
  end

  def extract_city_from_context(context)
    city_context = context.find { |c| c["id"].start_with?("place.") }
    city_context ? city_context["text"] : ""
  end

  def extract_state_from_context(context)
    region_context = context.find { |c| c["id"].start_with?("region.") }
    region_context ? region_context["short_code"]&.upcase : ""
  end

  def extract_zip_code_from_context(context)
    postcode_context = context.find { |c| c["id"].start_with?("postcode.") }
    postcode_context ? postcode_context["text"] : ""
  end
end
