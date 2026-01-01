class CreateCommunityGroupMemberships < ActiveRecord::Migration[8.0]
  def change
    create_table :community_group_memberships do |t|
      t.references :user, null: false, foreign_key: true
      t.references :community_group, null: false, foreign_key: true
      t.boolean :admin, default: false, null: false
      t.boolean :auto_joined, default: false, null: false
      t.timestamps
    end

    add_index :community_group_memberships, [ :user_id, :community_group_id ], unique: true, name: 'index_cgm_on_user_and_group'
    add_index :community_group_memberships, :admin
  end
end
