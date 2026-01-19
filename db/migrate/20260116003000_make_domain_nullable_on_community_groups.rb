class MakeDomainNullableOnCommunityGroups < ActiveRecord::Migration[8.0]
  def change
    # Domain is only used for auto-joining by email domain
    change_column_null :community_groups, :domain, true

    rename_column :community_groups, :group_type, :group_description
    change_column :community_groups, :group_description, :string, limit: 100
  end
end

