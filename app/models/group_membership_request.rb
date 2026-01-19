class GroupMembershipRequest < ApplicationRecord
  belongs_to :community_group
  belongs_to :requester, class_name: "User"

  normalizes :email_address, with: ->(e) { e.strip.downcase }

  validates :status, inclusion: { in: GroupMemberStatus.values }
  validates :requester_type, inclusion: { in: %w[Admin User] }
  validate :request_shape

  scope :requested, -> { where(status: GroupMemberStatus::REQUESTED) }
  scope :invited, -> { where(status: GroupMemberStatus::INVITED) }
  scope :accepted, -> { where(status: GroupMemberStatus::ACCEPTED) }
  scope :rejected, -> { where(status: GroupMemberStatus::REJECTED) }

  USER_REQUESTER_TYPE = "User"
  ADMIN_REQUESTER_TYPE = "Admin"

  def invited?
    status == GroupMemberStatus::INVITED
  end

  def requested?
    status == GroupMemberStatus::REQUESTED
  end

  def accepted?
    status == GroupMemberStatus::ACCEPTED
  end

  def rejected?
    status == GroupMemberStatus::REJECTED
  end

  def display_status
    GroupMemberStatus.display_status(status)
  end

  def accept
    update!(status: GroupMemberStatus::ACCEPTED, accepted_at: Time.current, responded_at: Time.current)
  rescue => e
    errors.add(:base, e.message)
    false
  end

  def reject
    update!(status: GroupMemberStatus::REJECTED, responded_at: Time.current)
  rescue => e
    errors.add(:base, e.message)
    false
  end

  private

  def request_shape
    case status
    when GroupMemberStatus::REQUESTED
      errors.add(:requester_type, "must be User for join requests") unless requester_type == "User"
    when GroupMemberStatus::INVITED
      errors.add(:requester_type, "must be Admin for invites") unless requester_type == "Admin"
      errors.add(:email_address, "can't be blank for invites") if email_address.blank?
    end
  end
end
