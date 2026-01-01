class CreateSubGroups < ActiveRecord::Migration[8.0]
  def change
    create_table :sub_groups do |t|
      t.string :name, null: false
      t.references :community_group, null: false, foreign_key: true
      t.timestamps
    end
    # Note: Rails automatically creates an index when using t.references with foreign_key
  end
end
