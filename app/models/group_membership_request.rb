class GroupMembershipRequest < ApplicationRecord
  enum :status, {
    requested: 0,
    invited: 1,
    accepted: 2,
    rejected: 3
  }, default: :requested, validate: true

  belongs_to :community_group
  belongs_to :requester, class_name: "User"

  normalizes :email_address, with: ->(e) { e.strip.downcase }

  validates :requester_type, inclusion: { in: %w[Admin User] }
  validate :request_shape

  USER_REQUESTER_TYPE = "User"
  ADMIN_REQUESTER_TYPE = "Admin"

  # Ransack allowlist for ActiveAdmin search/filter
  def self.ransackable_attributes(auth_object = nil)
    %w[
      id id_value community_group_id requester_id requester_type email_address
      message status responded_at accepted_at created_at updated_at
    ]
  end

  def self.ransackable_associations(auth_object = nil)
    ["community_group", "requester"]
  end

  def display_status
    GroupMemberStatus.display_status(status)
  end

  def accept
    update!(status: :accepted, accepted_at: Time.current, responded_at: Time.current)
  rescue => e
    errors.add(:base, e.message)
    false
  end

  def reject
    update!(status: :rejected, responded_at: Time.current)
  rescue => e
    errors.add(:base, e.message)
    false
  end

  private

  def request_shape
    if requested?
      errors.add(:requester_type, "must be User for join requests") unless requester_type == "User"
    elsif invited?
      errors.add(:requester_type, "must be Admin for invites") unless requester_type == "Admin"
      errors.add(:email_address, "can't be blank for invites") if email_address.blank?
    end
  end
end
