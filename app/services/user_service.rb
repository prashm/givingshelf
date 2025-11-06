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
      new_user = true
      # New user - create user
      password = SecureRandom.hex(16) # Temporary password for passwordless flow
      user = User.new(
        email_address: email,
        password: password,
        password_confirmation: password
      )

      # Skip validations for incomplete profile
      user.save!(validate: false)
    end

    p user
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
    return nil
  end

end
