class GroupMemberStatus < ActiveHash::Base
  REQUESTED = 0
  INVITED = 1
  ACCEPTED = 2
  REJECTED = 3

  self.data = [
    { value: REQUESTED, label: "Requested" },
    { value: INVITED, label: "Invited" },
    { value: ACCEPTED, label: "Accepted" },
    { value: REJECTED, label: "Rejected" }
  ]

  def self.display_status(status)
    self.all.find_by(value: status)&.label || "Unknown"
  end

  def self.values
    self.all.map { |s| s.value }
  end
end

