# Service to verify Cloudflare Turnstile CAPTCHA tokens
require "net/http"
require "uri"
require "json"

class CaptchaVerificationService
  TURNSTILE_VERIFY_URL = "https://challenges.cloudflare.com/turnstile/v0/siteverify".freeze

  def initialize(token, remote_ip = nil)
    @token = token
    @remote_ip = remote_ip
    @errors = []
  end

  attr_reader :errors

  def verify
    return false if @token.blank?

    secret_key = ENV["CLOUDFLARE_TURNSTILE_SECRET_KEY"]
    if secret_key.blank?
      @errors << "CAPTCHA verification not configured"
      return false
    end

    begin
      response = make_verification_request(secret_key)
      handle_verification_response(response)
    rescue StandardError => e
      Rails.logger.error "CAPTCHA verification error: #{e.message}"
      @errors << "CAPTCHA verification failed"
      false
    end
  end

  private

  def make_verification_request(secret_key)
    uri = URI(TURNSTILE_VERIFY_URL)
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = true

    request = Net::HTTP::Post.new(uri)
    request.set_form_data(
      secret: secret_key,
      response: @token,
      remoteip: @remote_ip
    )

    http.request(request)
  end

  def handle_verification_response(response)
    result = JSON.parse(response.body)

    if result["success"] == true
      true
    else
      error_codes = result["error-codes"] || []
      @errors.concat(error_codes)
      Rails.logger.warn "CAPTCHA verification failed: #{error_codes.join(', ')}"
      false
    end
  rescue JSON::ParserError => e
    Rails.logger.error "Failed to parse CAPTCHA response: #{e.message}"
    @errors << "Invalid CAPTCHA response"
    false
  end
end
