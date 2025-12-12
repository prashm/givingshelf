class Session < ApplicationRecord
  self.table_name = "user_sessions"
  belongs_to :user

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
