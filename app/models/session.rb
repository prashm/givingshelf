class Session < ApplicationRecord
  self.table_name = "user_sessions"
  belongs_to :user

  # A login session is invalid once it has gone this long without a request
  # (session_idle_timeout_minutes in config/application.yml).
  # updated_at is the last-activity timestamp (bumped by Authentication#resume_session).
  IDLE_TIMEOUT = Rails.configuration.x.application.fetch(:session_idle_timeout_minutes).minutes
  # Only bump updated_at when it is at least this stale, so we don't write on every request.
  ACTIVITY_TOUCH_INTERVAL = 5.minutes

  scope :idle_expired, -> { where(updated_at: ...IDLE_TIMEOUT.ago) }

  def idle_expired?
    updated_at < IDLE_TIMEOUT.ago
  end

  def activity_touch_due?
    updated_at < ACTIVITY_TOUCH_INTERVAL.ago
  end

  # Ransack allowlist for ActiveAdmin search/filter
  def self.ransackable_attributes(auth_object = nil)
    %w[
      id id_value user_id ip_address user_agent device_fingerprint
      suspicious_activity created_at updated_at
    ]
  end

  def self.ransackable_associations(auth_object = nil)
    [ "user" ]
  end
end
