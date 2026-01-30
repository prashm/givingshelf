require "rotp"
require "zxcvbn"

class User < ApplicationRecord
  has_secure_password
  has_one_attached :profile_picture
  has_many :sessions, class_name: "Session", foreign_key: "user_id", dependent: :destroy
  has_many :items, dependent: :destroy
  has_many :books, -> { where(type: "Book") }, class_name: "Item", foreign_key: "user_id", dependent: :destroy
  has_many :toys, -> { where(type: "Toy") }, class_name: "Item", foreign_key: "user_id", dependent: :destroy
  has_many :item_requests, class_name: "ItemRequest", foreign_key: "requester_id", dependent: :destroy
  has_many :received_item_requests, class_name: "ItemRequest", foreign_key: "owner_id", dependent: :destroy
  # Backward compatibility aliases
  has_many :book_requests, class_name: "ItemRequest", foreign_key: "requester_id", dependent: :destroy
  has_many :received_book_requests, class_name: "ItemRequest", foreign_key: "owner_id", dependent: :destroy
  has_many :messages, dependent: :destroy
  has_many :community_group_memberships, dependent: :destroy
  has_many :community_groups, through: :community_group_memberships
  has_many :admin_community_groups, -> { where(community_group_memberships: { admin: true }) }, through: :community_group_memberships, source: :community_group

  normalizes :email_address, with: ->(e) { e.strip.downcase }
  normalizes :first_name, :last_name, with: ->(name) { name.strip.titleize }
  normalizes :zip_code, with: ->(zip) { zip.strip }
  normalizes :street_address, :city, :state, with: ->(value) { value.present? ? value.strip : nil }

  # OTP Configuration
  OTP_EXPIRY_MINUTES = 5
  OTP_DRIFT = 30 # seconds of drift tolerance for TOTP

  validates :email_address, presence: true, uniqueness: true, format: { with: URI::MailTo::EMAIL_REGEXP }
  validates :first_name, presence: true, length: { minimum: 2, maximum: 50 }, if: -> { profile_completion_required? }
  validates :last_name, presence: true, length: { minimum: 2, maximum: 50 }, if: -> { profile_completion_required? }
  validates :zip_code, presence: true, format: { with: /\A\d{5}(-\d{4})?\z/, message: "must be a valid US zip code" }, if: -> { profile_completion_required? }
  validates :phone, format: { with: /\A\+?1?\d{10}\z/, message: "must be a valid US phone number (10 digits)" }, if: -> { phone.present? }
  validates :password, length: { minimum: 8 }, if: -> { password.present? }
  validate :password_strength, if: -> { password.present? }

  scope :verified, -> { where(verified: true) }
  scope :by_zip_code, ->(zip_code) { where(zip_code: zip_code) }
  scope :admin, -> { where(admin: true) }
  scope :group_admin, -> { where(group_admin: true) }

  # Ransack allowlist for ActiveAdmin search/filter
  def self.ransackable_attributes(auth_object = nil)
    # Exclude sensitive fields like password_digest and otp_secret
    %w[
      id id_value email_address first_name last_name zip_code phone
      street_address city state verified admin group_admin address_verified trust_score
      otp_attempts otp_sent_at created_at updated_at
    ]
  end

  after_create :auto_join_group_by_domain_after_creation
  after_update :auto_join_group_by_domain_if_email_changed, if: :saved_change_to_email_address?
  after_update :recalculate_trust_score, if: :saved_change_to_profile_fields?
  before_save :geocode_coordinates, if: :should_geocode_coordinates?

  def saved_change_to_profile_fields?
    saved_change_to_first_name? ||
    saved_change_to_last_name? ||
    saved_change_to_zip_code? ||
    saved_change_to_phone? ||
    saved_change_to_street_address? ||
    saved_change_to_city? ||
    saved_change_to_state? ||
    saved_change_to_address_verified?
  end

  def recalculate_trust_score
    calculate_trust_score!
  end

  def should_geocode_coordinates?
    zip_code.present? && (zip_code_changed? || latitude.nil? || longitude.nil?)
  end

  def geocode_coordinates
    service = AddressVerificationService.new
    coords = service.geocode_zip_code(zip_code)
    if coords
      self.latitude = coords[:latitude]
      self.longitude = coords[:longitude]
    else
      Rails.logger.error "Geocoding failed for User #{id} and ZIP code #{zip_code}: #{service.errors.to_sentence}"
    end
  end

  def full_name
    "#{first_name} #{last_name}"
  end

  def display_name
    full_name.presence || email_address.split("@").first
  end

  def location
    zip_code
  end

  def profile_complete?
    first_name.present? &&
    last_name.present? &&
    zip_code.present?
    # Phone and address fields are optional
  end

  def calculate_trust_score!
    score = 0

    # Basic profile fields (60 points total)
    score += 5 if first_name.present?
    score += 5 if last_name.present?
    score += 10 if zip_code.present?
    score += 10 if phone.present?
    score += 10 if profile_picture.attached?

    # Address fields (30 points total)
    score += 10 if street_address.present?
    score += 10 if city.present?
    score += 10 if state.present?

    # Address verification bonus (10 points)
    score += 10 if address_verified?

    # Group domain bonus (50 points) - if user is verified and member of group with matching domain
    if verified? && email_address.present?
      email_domain = email_address.split("@").last
      if community_groups.exists?(domain: email_domain)
        score += 50
      end
    end

    # Cap at 100
    self.trust_score = [ score, 100 ].min
    save!
  end

  # OTP Methods
  def generate_otp_secret!
    self.otp_secret ||= ROTP::Base32.random
    save!
    otp_secret
  end

  def current_otp
    return nil unless otp_secret.present?
    totp = ROTP::TOTP.new(otp_secret, issuer: "GivingShelf Community")
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

    totp = ROTP::TOTP.new(otp_secret, issuer: "GivingShelf Community")

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

  def profile_completion_required?
    # Only require profile fields when they're being set (not during initial email-only registration)
    first_name.present? || last_name.present? || zip_code.present? || phone.present?
  end

  def invitation_request_for(group)
    GroupMembershipRequest.invited.find_by(community_group: group, email_address: email_address)
  end

  def join_request_for(group)
    GroupMembershipRequest.requested.find_by(community_group: group,
    requester: self, requester_type: GroupMembershipRequest::USER_REQUESTER_TYPE)
  end

  def auto_join_group_by_domain!
    return unless email_address.present?
    group = CommunityGroup.by_domain(email_address.split("@").last).first
    if group
      community_group_memberships.create!(
        community_group: group,
        admin: false,
        auto_joined: true
      )
      invitation_request_for(group)&.accept
    end
  end

  def password_reset_token
    signed_id(expires_in: 15.minutes, purpose: :password_reset)
  end

  def self.find_by_password_reset_token!(token)
    find_signed!(token, purpose: :password_reset)
  end

  private

  def password_strength
    return unless password.present?
    # Skip strength validation if password doesn't meet minimum length
    return if password.length < 8

    result = Zxcvbn.test(password, [ email_address, first_name, last_name ].compact)
    # Score: 0 = too guessable, 1 = very guessable, 2 = somewhat guessable,
    # 3 = safely unguessable, 4 = very unguessable
    # Require at least score 2 (somewhat guessable) for acceptance
    if result.score < 2
      feedback_parts = []
      feedback_parts << result.feedback.warning if result.feedback.warning.present?
      feedback_parts << "Please use a stronger password with a mix of letters, numbers, and symbols."
      errors.add(:password, "is too weak. #{feedback_parts.join("; ")}")
    end
  end

  def auto_join_group_by_domain_after_creation
    auto_join_group_by_domain!
    calculate_trust_score! # Recalculate trust score after auto-join
  end

  def auto_join_group_by_domain_if_email_changed
    auto_join_group_by_domain!
    calculate_trust_score! # Recalculate trust score after auto-join
  end
end
