class CreateGroupMembershipRequests < ActiveRecord::Migration[8.0]
  def change
    create_table :group_membership_requests do |t|
      t.references :community_group, null: false, foreign_key: true
      t.references :requester, null: false, foreign_key: { to_table: :users }
      t.string :requester_type, null: false

      t.string :email_address
      t.text :message
      t.integer :status, null: false, default: 0
      t.datetime :responded_at
      t.datetime :accepted_at

      t.timestamps
    end

    add_index :group_membership_requests, :status
    add_index :group_membership_requests, :email_address
    add_index :group_membership_requests, :requester_type
    add_index :group_membership_requests, [ :community_group_id, :status ]

    # Only allow one open join-request per user per group
    add_index :group_membership_requests,
              [ :community_group_id, :requester_id ],
              unique: true,
              where: "status = 0 AND requester_type = 'User'",
              name: "index_gmr_unique_requested_by_user_and_group"

    # Only allow one open invite per email per group
    add_index :group_membership_requests,
              [ :community_group_id, :email_address ],
              unique: true,
              where: "status = 1 AND email_address IS NOT NULL",
              name: "index_gmr_unique_invited_by_email_and_group"
  end
end

