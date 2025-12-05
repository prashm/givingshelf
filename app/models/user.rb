require "rotp"

class User < ApplicationRecord
  has_secure_password
  has_one_attached :profile_picture
  has_many :sessions, class_name: "Session", foreign_key: "user_id", dependent: :destroy
  has_many :books, dependent: :destroy
  has_many :book_requests, class_name: "BookRequest", foreign_key: "requester_id", dependent: :destroy
  has_many :received_book_requests, class_name: "BookRequest", foreign_key: "owner_id", dependent: :destroy
  has_many :messages, dependent: :destroy

  normalizes :email_address, with: ->(e) { e.strip.downcase }
  normalizes :first_name, :last_name, with: ->(name) { name.strip.titleize }
  normalizes :zip_code, with: ->(zip) { zip.strip }

  # OTP Configuration
  OTP_EXPIRY_MINUTES = 5
  OTP_DRIFT = 30 # seconds of drift tolerance for TOTP

  validates :email_address, presence: true, uniqueness: true, format: { with: URI::MailTo::EMAIL_REGEXP }
  validates :first_name, presence: true, length: { minimum: 2, maximum: 50 }, if: -> { profile_completion_required? }
  validates :last_name, presence: true, length: { minimum: 2, maximum: 50 }, if: -> { profile_completion_required? }
  validates :zip_code, presence: true, format: { with: /\A\d{5}(-\d{4})?\z/, message: "must be a valid US zip code" }, if: -> { profile_completion_required? }
  validates :phone, format: { with: /\A\+?1?\d{10}\z/, message: "must be a valid US phone number (10 digits)" }, if: -> { phone.present? }
  validates :password, length: { minimum: 8 }, if: -> { password.present? }

  scope :verified, -> { where(verified: true) }
  scope :by_zip_code, ->(zip_code) { where(zip_code: zip_code) }

  def full_name
    "#{first_name} #{last_name}"
  end

  def display_name
    verified? ? full_name : "#{first_name} #{last_name[0]}."
  end

  def location
    zip_code
  end

  def profile_complete?
    first_name.present? &&
    last_name.present? &&
    zip_code.present?
    # Phone is optional
  end

  # OTP Methods
  def generate_otp_secret!
    self.otp_secret ||= ROTP::Base32.random
    save!
    otp_secret
  end

  def current_otp
    return nil unless otp_secret.present?
    totp = ROTP::TOTP.new(otp_secret, issuer: "BookShare Community")
    totp.now
  end

  def send_otp!
    generate_otp_secret! unless otp_secret.present?
    otp_code = current_otp
    update!(
      otp_sent_at: Time.current,
      otp_attempts: 0
    )
    OtpMailer.send_otp(self, otp_code).deliver_now
    otp_code
  end

  def verify_otp(provided_otp)
    return false unless otp_secret.present?
    return false unless otp_sent_at.present?

    # Check if OTP has expired (5 minutes)
    if otp_sent_at < OTP_EXPIRY_MINUTES.minutes.ago
      return false
    end

    totp = ROTP::TOTP.new(otp_secret, issuer: "BookShare Community")

    # Verify with drift tolerance
    if totp.verify(provided_otp.to_s, drift_behind: OTP_DRIFT, drift_ahead: OTP_DRIFT)
      # Reset OTP fields after successful verification and mark as verified
      update!(
        otp_sent_at: nil,
        otp_attempts: 0,
        verified: true
      )
      true
    else
      # Increment attempts on failure
      increment!(:otp_attempts)
      false
    end
  end

  def otp_expired?
    return true unless otp_sent_at.present?
    otp_sent_at < OTP_EXPIRY_MINUTES.minutes.ago
  end

  def can_resend_otp?
    return true unless otp_sent_at.present?
    otp_sent_at < 20.seconds.ago
  end

  private

  def profile_completion_required?
    # Only require profile fields when they're being set (not during initial email-only registration)
    first_name.present? || last_name.present? || zip_code.present? || phone.present?
  end
end
