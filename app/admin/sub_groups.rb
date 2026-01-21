ActiveAdmin.register SubGroup do
  permit_params :name, :community_group_id

  index do
    selectable_column
    id_column
    column :name
    column :community_group do |sub_group|
      link_to sub_group.community_group.name, admin_community_group_path(sub_group.community_group)
    end
    column :members_count do |sub_group|
      sub_group.community_group.community_group_memberships.where(sub_group: sub_group).count
    end
    column :created_at
    actions
  end

  filter :name
  filter :community_group
  filter :created_at

  show do
    attributes_table do
      row :id
      row :name
      row :community_group do |sub_group|
        link_to sub_group.community_group.name, admin_community_group_path(sub_group.community_group)
      end
      row :members_count do |sub_group|
        sub_group.community_group.community_group_memberships.where(sub_group: sub_group).count
      end
      row :created_at
      row :updated_at
    end
  end

  form do |f|
    f.inputs "Sub Group Details" do
      f.input :name
      f.input :community_group, collection: CommunityGroup.all.map { |g| [g.name, g.id] }
    end
    f.actions
  end
end
