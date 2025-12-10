class Api::LocationController < ApplicationController
  before_action :require_authentication, only: [ :mapbox_token ]

  def detect_zip
    # If coordinates are provided (from browser geolocation), use reverse geocoding
    if params[:latitude].present? && params[:longitude].present?
      return detect_zip_from_coordinates(params[:latitude], params[:longitude])
    end

    # Otherwise, use IP-based geolocation
    ip_address = request.remote_ip

    # Handle localhost/development case - try to use a test IP if provided
    if Rails.env.development? && (ip_address == "127.0.0.1" || ip_address == "::1")
      # Allow test IP override via query parameter for local testing
      if params[:test_ip].present?
        ip_address = params[:test_ip]
      else
        Rails.logger.info "DEBUG: Localhost detected, suggest using browser geolocation or test_ip parameter"
        render json: { zip_code: nil, error: "Unable to detect location from localhost IP. Use browser geolocation or provide test_ip parameter." }
        return
      end
    end

    begin
      # Temporarily override remote_ip for geocoder lookup if test_ip is provided
      if Rails.env.development? && params[:test_ip].present?
        original_remote_ip = request.remote_ip
        request.instance_variable_set(:@remote_ip, params[:test_ip])
      end

      location = request.location

      # Restore original remote_ip
      if Rails.env.development? && params[:test_ip].present?
        request.instance_variable_set(:@remote_ip, original_remote_ip)
      end

      if location && location.postal_code.present?
        Rails.logger.info "DEBUG: Detected zip code: #{location.postal_code} from IP: #{ip_address}"
        render json: { zip_code: location.postal_code }
      else
        Rails.logger.warn "DEBUG: Unable to detect zip code for IP: #{ip_address}"
        render json: { zip_code: nil, error: "Unable to detect zip code" }
      end
    rescue => e
      Rails.logger.error "Error detecting zip code: #{e.message}"
      Rails.logger.error e.backtrace.join("\n")
      render json: { zip_code: nil, error: "Failed to detect location" }
    end
  end

  def mapbox_token
    mapbox_token = Rails.application.credentials.mapbox&.access_token || ENV["MAPBOX_ACCESS_TOKEN"]

    unless mapbox_token.present?
      render json: { error: "Mapbox token not configured" }, status: :service_unavailable
      return
    end

    # Create a JWT token that expires in 1 hour
    payload = {
      mapbox_token: mapbox_token,
      exp: 1.hour.from_now.to_i,
      iat: Time.current.to_i
    }

    # Use Rails secret key base for signing (or a separate secret)
    secret = Rails.application.secret_key_base
    token = JWT.encode(payload, secret, "HS256")

    render json: { token: token }
  end

  private

  def detect_zip_from_coordinates(latitude, longitude)
    begin
      # Use Geocoder to reverse geocode coordinates to get zip code
      results = Geocoder.search([ latitude.to_f, longitude.to_f ])

      if results.any?
        result = results.first
        zip_code = result.postal_code || result.postcode

        if zip_code.present?
          Rails.logger.info "DEBUG: Detected zip code: #{zip_code} from coordinates: #{latitude}, #{longitude}"
          render json: { zip_code: zip_code }
        else
          Rails.logger.warn "DEBUG: No zip code found for coordinates: #{latitude}, #{longitude}"
          render json: { zip_code: nil, error: "Unable to detect zip code from coordinates" }
        end
      else
        Rails.logger.warn "DEBUG: No geocoding results for coordinates: #{latitude}, #{longitude}"
        render json: { zip_code: nil, error: "Unable to geocode coordinates" }
      end
    rescue => e
      Rails.logger.error "Error reverse geocoding coordinates: #{e.message}"
      Rails.logger.error e.backtrace.join("\n")
      render json: { zip_code: nil, error: "Failed to geocode coordinates" }
    end
  end
end
