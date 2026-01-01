class CreateCommunityGroups < ActiveRecord::Migration[8.0]
  def change
    create_table :community_groups do |t|
      t.string :name, null: false
      t.string :group_type
      t.string :domain, null: false
      t.string :short_name, null: false
      t.timestamps
    end

    add_index :community_groups, :domain, unique: true
    add_index :community_groups, :short_name, unique: true
  end
end

