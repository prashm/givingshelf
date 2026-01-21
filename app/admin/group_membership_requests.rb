ActiveAdmin.register GroupMembershipRequest do
  permit_params :community_group_id, :requester_id, :requester_type, :email_address, :message, :status

  index do
    selectable_column
    id_column
    column :community_group do |request|
      link_to request.community_group.name, admin_community_group_path(request.community_group)
    end
    column :requester do |request|
      link_to request.requester.email_address, admin_user_path(request.requester)
    end
    column :requester_type
    column :email_address
    column :status do |request|
      request.display_status
    end
    column :created_at
    actions
  end

  filter :community_group
  filter :requester
  filter :requester_type, as: :select, collection: %w[Admin User]
  filter :email_address
  filter :status, as: :select, collection: -> {
    GroupMemberStatus.all.map { |s| [s.label, s.value] }
  }
  filter :created_at

  show do
    attributes_table do
      row :id
      row :community_group do |request|
        link_to request.community_group.name, admin_community_group_path(request.community_group)
      end
      row :requester do |request|
        link_to request.requester.email_address, admin_user_path(request.requester)
      end
      row :requester_type
      row :email_address
      row :message
      row :status do |request|
        request.display_status
      end
      row :responded_at
      row :accepted_at
      row :created_at
      row :updated_at
    end
  end

  form do |f|
    f.inputs "Group Membership Request Details" do
      f.input :community_group, collection: CommunityGroup.all.map { |g| [g.name, g.id] }
      f.input :requester, collection: User.all.map { |u| [u.email_address, u.id] }
      f.input :requester_type, as: :select, collection: %w[Admin User]
      f.input :email_address
      f.input :message
      f.input :status, as: :select, collection: GroupMemberStatus.all.map { |s| [s.label, s.value] }
    end
    f.actions
  end
end
