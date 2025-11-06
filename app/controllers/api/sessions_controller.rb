class Api::SessionsController < ApplicationController
  skip_before_action :require_authentication, only: [:create, :verify_otp, :resend_otp]

  def create
    email = sanitize_email(params[:email])
    user = user_service.find_or_create_user_by_email(email)

    if user
      # Existing user - send OTP
      user.send_otp!
      message = user_service.new_user ? 'User created. ' : ''
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
      # OTP verified - create session
      start_new_session_for(user)
      render json: {
        user: user_json(user),
        message: "Logged in successfully"
      }
    else
      render json: { 
        error: "Invalid verification code",
        attempts_remaining: [3 - user.otp_attempts, 0].max
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
        seconds_remaining: [seconds_remaining, 0].max
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