ActiveAdmin.register CommunityGroup do
  permit_params :name, :short_name, :domain, :group_description, :public

  index do
    selectable_column
    id_column
    column :name
    column :short_name
    column :domain
    column :public
    column :members_count do |group|
      group.members.count
    end
    column :sub_groups_count do |group|
      group.sub_groups.count
    end
    column :created_at
    actions
  end

  filter :name
  filter :short_name
  filter :domain
  filter :public
  filter :created_at

  show do
    attributes_table do
      row :id
      row :name
      row :short_name
      row :domain
      row :group_description
      row :public
      row :members_count do |group|
        group.members.count
      end
      row :sub_groups_count do |group|
        group.sub_groups.count
      end
      row :created_at
      row :updated_at
    end
  end

  form do |f|
    f.inputs "Community Group Details" do
      f.input :name
      f.input :short_name
      f.input :domain
      f.input :group_description
      f.input :public
    end
    f.actions
  end
end
