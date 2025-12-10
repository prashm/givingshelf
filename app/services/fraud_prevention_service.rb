# Service to detect suspicious login patterns based on IP and device fingerprint
class FraudPreventionService
  # Thresholds for suspicious activity detection
  RAPID_IP_CHANGE_WINDOW = 1.hour # Window to check for rapid IP changes
  MAX_IPS_PER_FINGERPRINT = 5 # Max different IPs per device fingerprint in window
  MAX_FINGERPRINTS_PER_IP = 10 # Max different devices per IP in window
  SUSPICIOUS_IP_PATTERNS = [
    # Common proxy/VPN patterns (basic heuristics)
    /\A\d+\.\d+\.\d+\.0\z/, # Likely VPN gateway
  ].freeze

  def initialize(device_fingerprint, ip_address, user_id = nil)
    @device_fingerprint = device_fingerprint
    @ip_address = ip_address
    @user_id = user_id
    @errors = []
  end

  attr_reader :errors

  # Check if this login attempt is suspicious
  def suspicious_login?
    return false if @device_fingerprint.blank? || @ip_address.blank?

    checks = [
      suspicious_ip_pattern?,
      rapid_ip_change?,
      multiple_devices_same_ip?,
      same_device_multiple_ips?
    ]

    suspicious = checks.any?

    if suspicious
      log_suspicious_activity
    end

    suspicious
  end

  # Check if IP matches suspicious patterns (proxy/VPN heuristics)
  def suspicious_ip_pattern?
    return false if @ip_address.blank?

    SUSPICIOUS_IP_PATTERNS.any? { |pattern| @ip_address.match?(pattern) }
  end

  # Check for rapid IP changes from same device
  def rapid_ip_change?
    return false if @device_fingerprint.blank?

    recent_sessions = Session
      .where(device_fingerprint: @device_fingerprint)
      .where('created_at > ?', RAPID_IP_CHANGE_WINDOW.ago)
      .distinct
      .pluck(:ip_address)
      .compact

    # If device has been used from too many different IPs recently
    recent_sessions.count > MAX_IPS_PER_FINGERPRINT
  end

  # Check if multiple different devices are logging in from same IP
  def multiple_devices_same_ip?
    return false if @ip_address.blank?

    recent_fingerprints = Session
      .where(ip_address: @ip_address)
      .where('created_at > ?', RAPID_IP_CHANGE_WINDOW.ago)
      .where.not(device_fingerprint: nil)
      .distinct
      .pluck(:device_fingerprint)
      .compact

    # If too many different devices from same IP
    recent_fingerprints.count > MAX_FINGERPRINTS_PER_IP
  end

  # Check if same device is being used from multiple IPs (potential account sharing or compromise)
  def same_device_multiple_ips?
    return false if @device_fingerprint.blank? || @user_id.blank?

    # Check if this device has been used with different IPs for this user
    user_sessions = Session
      .where(user_id: @user_id, device_fingerprint: @device_fingerprint)
      .where('created_at > ?', 24.hours.ago)
      .distinct
      .pluck(:ip_address)
      .compact

    # If same device with more than 3 different IPs in 24 hours
    user_sessions.count > 3
  end

  # Get risk score (0-100, higher = more risky)
  def risk_score
    score = 0

    score += 30 if suspicious_ip_pattern?
    score += 25 if rapid_ip_change?
    score += 25 if multiple_devices_same_ip?
    score += 20 if same_device_multiple_ips?

    score
  end

  # Log suspicious activity for monitoring
  def log_suspicious_activity
    Rails.logger.warn({
      event: 'suspicious_login_attempt',
      device_fingerprint: @device_fingerprint&.first(16), # Log only first 16 chars for privacy
      ip_address: @ip_address,
      user_id: @user_id,
      risk_score: risk_score,
      checks: {
        suspicious_ip: suspicious_ip_pattern?,
        rapid_ip_change: rapid_ip_change?,
        multiple_devices: multiple_devices_same_ip?,
        same_device_multiple_ips: same_device_multiple_ips?
      }
    }.to_json)
  end

  # Get recent sessions for a device fingerprint
  def recent_sessions_for_device(limit: 10)
    return [] if @device_fingerprint.blank?

    Session
      .where(device_fingerprint: @device_fingerprint)
      .order(created_at: :desc)
      .limit(limit)
  end

  # Get recent sessions for an IP address
  def recent_sessions_for_ip(limit: 10)
    return [] if @ip_address.blank?

    Session
      .where(ip_address: @ip_address)
      .order(created_at: :desc)
      .limit(limit)
  end
end
