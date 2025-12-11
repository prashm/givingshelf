# Mapbox Geocoding API Configuration
# Get your API key from: https://account.mapbox.com/access-tokens/
# Add it to your credentials: rails credentials:edit
# Or set MAPBOX_ACCESS_TOKEN environment variable

require "uri"
require "cgi"

module Mapbox
  ACCESS_TOKEN = Rails.application.credentials.mapbox&.access_token || ENV["MAPBOX_ACCESS_TOKEN"]

  GEOCODING_API_BASE = "https://api.mapbox.com/geocoding/v5/mapbox.places"

  def self.geocoding_url(endpoint, params = {})
    params[:access_token] = ACCESS_TOKEN

    # URL encode the endpoint (address query) for the path
    # Use URI.encode_www_form_component and replace + with %20 for proper URL path encoding
    # (form encoding uses + for spaces, but URL paths should use %20)
    encoded_endpoint = URI.encode_www_form_component(endpoint.to_s).gsub("+", "%20")

    # Build query string with properly encoded parameters
    query_parts = params.map { |k, v| "#{URI.encode_www_form_component(k.to_s)}=#{URI.encode_www_form_component(v.to_s)}" }
    query_string = query_parts.join("&")

    "#{GEOCODING_API_BASE}/#{encoded_endpoint}.json?#{query_string}"
  end
end
