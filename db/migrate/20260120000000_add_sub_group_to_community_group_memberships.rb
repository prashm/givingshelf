class AddSubGroupToCommunityGroupMemberships < ActiveRecord::Migration[8.0]
  def change
    add_reference :community_group_memberships, :sub_group, foreign_key: true, null: true
  end
end

