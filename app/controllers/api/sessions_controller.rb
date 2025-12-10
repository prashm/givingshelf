class Api::SessionsController < ApplicationController
  skip_before_action :require_authentication, only: [ :create, :verify_otp, :resend_otp ]

  # Rate limiting: 5 attempts per 15 minutes per IP for login
  rate_limit to: 5, within: 15.minutes, only: :create,
    with: -> {
      render json: {
        error: "Too many login attempts. Please try again later.",
        retry_after: 15.minutes.to_i
      }, status: :too_many_requests
    }

  # Rate limiting: 10 attempts per 15 minutes per IP for OTP verification
  rate_limit to: 10, within: 15.minutes, only: :verify_otp,
    with: -> {
      render json: {
        error: "Too many verification attempts. Please try again later.",
        retry_after: 15.minutes.to_i
      }, status: :too_many_requests
    }

  # Rate limiting: 3 attempts per 10 minutes per IP for OTP resend
  rate_limit to: 3, within: 10.minutes, only: :resend_otp,
    with: -> {
      render json: {
        error: "Too many resend requests. Please try again later.",
        retry_after: 10.minutes.to_i
      }, status: :too_many_requests
    }

  def create
    email = sanitize_email(params[:email])

    # Verify CAPTCHA if token is provided
    if ENV["CLOUDFLARE_TURNSTILE_SECRET_KEY"].present?
      # Only require CAPTCHA in production and staging
      require_captcha = Rails.env.production? || Rails.env.staging?

      if require_captcha
        captcha_token = params[:captcha_token]
        if captcha_token.blank?
          render json: {
            error: "Security verification required"
          }, status: :bad_request
          return
        end

        captcha_service = CaptchaVerificationService.new(captcha_token, request.remote_ip)
        unless captcha_service.verify
          render json: {
            error: "Security verification failed. Please try again.",
            captcha_errors: captcha_service.errors
          }, status: :unprocessable_entity
          return
        end
      else
        # In development/test: log if token provided but don't require it
        if params[:captcha_token].present?
          Rails.logger.debug "CAPTCHA token provided in #{Rails.env} but not verified"
        end
      end
    end

    # Check for suspicious patterns before processing login (monitoring only, don't block)
    device_fingerprint = params[:device_fingerprint]
    begin
      if device_fingerprint.present?
        fraud_service = FraudPreventionService.new(device_fingerprint, request.remote_ip)
        if fraud_service.suspicious_login?
          # Log but don't block - allow OTP flow to proceed
          # Suspicious flag will be set when session is created after OTP verification
          Rails.logger.warn "Suspicious login pattern detected for email: #{email}, IP: #{request.remote_ip}, Risk score: #{fraud_service.risk_score}"
        end
      end
    rescue StandardError => e
      # Don't fail login if fraud detection has issues
      Rails.logger.error "Fraud detection error: #{e.message}"
    end

    user = user_service.find_or_create_user_by_email(email)

    if user
      # Existing user - send OTP
      user.send_otp!
      message = user_service.new_user ? "User created. " : ""
      message << "Verification code sent to the email #{user.email_address}."
      logger.info message
      render json: {
        message: message,
        requires_otp: true,
        email: email,
        profile_incomplete: !user.profile_complete?
      }, status: :created
    else
      message = "Failed to fetch or create user with email #{email}."
      message << " Error: #{user_service.errors.to_sentence}"
      logger.info message
        render json: {
          error: "Failed to fetch or create user with email #{email}",
          errors: user_service.errors
        }, status: :unprocessable_entity
    end
  end

  def verify_otp
    email = sanitize_email(params[:email])
    verified = user_service.verify_otp(email, params[:otp_code]&.strip)

    if user_service.errors.present?
      render json: { error: user_service.errors.to_sentence }, status: :unprocessable_entity
      return
    end

    user = user_service.user

    if verified
      # OTP verified - create session with device fingerprint
      device_fingerprint = params[:device_fingerprint]

      # Check for suspicious activity before creating session
      suspicious = false
      begin
        if device_fingerprint.present?
          fraud_service = FraudPreventionService.new(device_fingerprint, request.remote_ip, user.id)
          suspicious = fraud_service.suspicious_login?
          if suspicious
            Rails.logger.warn "Suspicious login detected for user #{user.id}, IP: #{request.remote_ip}, Risk score: #{fraud_service.risk_score}"
          end
        end
      rescue StandardError => e
        # Log error but continue with login
        Rails.logger.error "Fraud detection error during OTP verification: #{e.message}"
      end

      start_new_session_for(user, device_fingerprint: device_fingerprint, suspicious_activity: suspicious)

      render json: {
        user: user_json(user),
        message: "Logged in successfully"
      }
    else
      render json: {
        error: "Invalid verification code",
        attempts_remaining: [ 3 - user.otp_attempts, 0 ].max
      }, status: :unauthorized
    end
  end

  def resend_otp
    email = sanitize_email(params[:email])

    unless email.present?
      render json: { error: "Email is required" }, status: :unprocessable_entity
      return
    end

    user = User.find_by(email_address: email)

    unless user
      render json: { error: "User not found" }, status: :not_found
      return
    end

    unless user.can_resend_otp?
      seconds_remaining = 20 - (Time.current - user.otp_sent_at).to_i
      render json: {
        error: "Please wait before requesting a new code",
        seconds_remaining: [ seconds_remaining, 0 ].max
      }, status: :too_many_requests
      return
    end

    user.send_otp!
    render json: {
      message: "New verification code sent to your email"
    }
  end

  def destroy
    terminate_session
    render json: { message: "Logged out successfully" }
  end

  private

  def user_service
    @user_service ||= UserService.new
  end

  def sanitize_email(email)
    email&.strip&.downcase
  end

  def user_json(user)
    {
      id: user.id,
      email_address: user.email_address,
      first_name: user.first_name,
      last_name: user.last_name,
      full_name: user.full_name,
      display_name: user.display_name,
      zip_code: user.zip_code,
      phone: user.phone,
      verified: user.verified?,
      profile_complete: user.profile_complete?,
      created_at: user.created_at,
      updated_at: user.updated_at
    }
  end
end
