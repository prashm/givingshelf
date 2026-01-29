Geocoder.configure(
  # Use ipapi.com for IP lookups (free, no API key needed)
  ip_lookup: :ipapi_com,

  # Use Nominatim (OpenStreetMap) for address/coordinate lookups (free, no API key needed)
  lookup: :nominatim,

  # Nominatim requires a user agent (required by their usage policy)
  http_headers: {
    "User-Agent" => "GivingShelf App (noreply@givingshelf.net)"
  },

  # Timeout for geocoding service
  timeout: 5,

  # Units for distance calculations
  units: :km,

  # Cache configuration (optional, can improve performance)
  cache: Rails.cache,
  cache_prefix: "geocoder:"
)
