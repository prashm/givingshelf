class CreateGrowthStats < ActiveRecord::Migration[8.1]
  def change
    create_table :growth_stats do |t|
      t.string :stat_type, null: false
      t.string :stat_name, null: false
      t.string :stat_value, null: false
      t.references :community_group, null: true, foreign_key: true
      t.datetime :computed_at, null: false
      t.timestamps
    end

    add_index :growth_stats, [ :stat_type, :stat_name ],
      unique: true,
      where: "community_group_id IS NULL",
      name: "index_growth_stats_global_unique"

    add_index :growth_stats, [ :stat_type, :stat_name, :community_group_id ],
      unique: true,
      where: "community_group_id IS NOT NULL",
      name: "index_growth_stats_per_group_unique"
  end
end
