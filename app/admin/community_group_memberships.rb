ActiveAdmin.register CommunityGroupMembership do
  permit_params :user_id, :community_group_id, :admin, :auto_joined, :sub_group_id, :group_membership_request_id

  index do
    selectable_column
    id_column
    column :user do |membership|
      link_to membership.user.email_address, admin_user_path(membership.user)
    end
    column :community_group do |membership|
      link_to membership.community_group.name, admin_community_group_path(membership.community_group)
    end
    column :sub_group do |membership|
      membership.sub_group&.name
    end
    column :admin
    column :auto_joined
    column :created_at
    actions
  end

  filter :user
  filter :community_group
  filter :sub_group
  filter :admin
  filter :auto_joined
  filter :created_at

  show do
    attributes_table do
      row :id
      row :user do |membership|
        link_to membership.user.email_address, admin_user_path(membership.user)
      end
      row :community_group do |membership|
        link_to membership.community_group.name, admin_community_group_path(membership.community_group)
      end
      row :sub_group do |membership|
        membership.sub_group ? link_to(membership.sub_group.name, admin_sub_group_path(membership.sub_group)) : nil
      end
      row :admin
      row :auto_joined
      row :group_membership_request do |membership|
        if membership.group_membership_request
          link_to "Request ##{membership.group_membership_request.id}", admin_group_membership_request_path(membership.group_membership_request)
        end
      end
      row :created_at
      row :updated_at
    end
  end

  form do |f|
    f.inputs "Community Group Membership Details" do
      f.input :user, collection: User.all.map { |u| [ u.email_address, u.id ] }
      f.input :community_group, collection: CommunityGroup.all.map { |g| [ g.name, g.id ] }
      f.input :sub_group, collection: SubGroup.all.map { |sg| [ "#{sg.community_group.name} - #{sg.name}", sg.id ] }, include_blank: true
      f.input :admin
      f.input :auto_joined
      f.input :group_membership_request, collection: GroupMembershipRequest.all.map { |gmr| [ "Request ##{gmr.id}", gmr.id ] }, include_blank: true
    end
    f.actions
  end
end
