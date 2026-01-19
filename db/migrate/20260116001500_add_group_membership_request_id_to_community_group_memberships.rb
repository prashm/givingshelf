class AddGroupMembershipRequestIdToCommunityGroupMemberships < ActiveRecord::Migration[8.0]
  def change
    add_reference :community_group_memberships,
                  :group_membership_request,
                  null: true,
                  foreign_key: true
  end
end

