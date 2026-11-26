class GroupMembershipRequest < ApplicationRecord
  belongs_to :community_group
  belongs_to :requester, class_name: "User"

  normalizes :email_address, with: ->(e) { e.strip.downcase }

  enum :status, { requested: 0, invited: 1, accepted: 2, rejected: 3 }, validate: true

  validates :requester_type, inclusion: { in: %w[Admin User] }
  validate :request_shape

  USER_REQUESTER_TYPE = "User"
  ADMIN_REQUESTER_TYPE = "Admin"

  # Lets ActiveAdmin filter by status name; the enum type maps it to the stored value.
  ransacker :status, type: :string do |parent|
    parent.table[:status]
  end

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

  # Display label for a status name, e.g. "Invited".
  def self.status_label(status)
    statuses.key?(status.to_s) ? status.to_s.titleize : "Unknown"
  end

  # [label, name] pairs for select inputs.
  def self.status_options
    statuses.keys.map { |name| [ status_label(name), name ] }
  end

  def display_status
    self.class.status_label(status)
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
    case status
    when "requested"
      errors.add(:requester_type, "must be User for join requests") unless requester_type == "User"
    when "invited"
      errors.add(:requester_type, "must be Admin for invites") unless requester_type == "Admin"
      errors.add(:email_address, "can't be blank for invites") if email_address.blank?
    end
  end
end
