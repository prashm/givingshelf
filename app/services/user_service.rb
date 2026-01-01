class UserService
  attr_accessor :user
  attr_reader :errors, :new_user

  def initialize(user = nil)
    @user = user
    @errors = []
  end

  def find_or_create_user_by_email(email)
    if email.blank? || !email.match?(URI::MailTo::EMAIL_REGEXP)
      @errors << "Invalid email address"
      return
    end

    user = User.find_by(email_address: email)
    self.user = user

    unless user
      # New user - create user
      password = SecureRandom.hex(16) # Temporary password for passwordless flow
      user = User.new(
        email_address: email,
        password: password,
        password_confirmation: password
      )

      # Skip validations for incomplete profile
      user.save!(validate: false)
      # Note: auto_join_groups_by_domain! is called via after_create callback
    end

    user
  rescue => e
    # Perhaps user email already exists?
    @errors << e.message
    nil
  end

  def verify_otp(email, otp_code)
    raise "Email and OTP code are required" if email.blank? || otp_code.blank?

    user = User.find_by(email_address: email)
    self.user = user

    @errors << "User not found" unless user

    raise "OTP code has expired. Please request a new one." if user.otp_expired?

    user.verify_otp(otp_code)
  rescue => e
    @errors << e.message
    nil
  end

  def update_user(user_params)
    user_params = user_params.with_indifferent_access
    # Verify address if address fields are provided
    if user_params[:street_address].present? && user_params[:city].present? && user_params[:state].present?
      address_params = {
        street_address: user_params[:street_address],
        city: user_params[:city],
        state: user_params[:state],
        zip_code: user_params[:zip_code] || self.user.zip_code
      }
      user_params[:address_verified] = AddressVerificationService.new.verify(address_params, address_params[:zip_code])
    end
    user.update!(user_params)
    true
  rescue => e
    @errors << e.message
    false
  end
end
