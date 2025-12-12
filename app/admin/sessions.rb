ActiveAdmin.register Session, as: "UserSession" do
  # Sessions are read-only for security reasons
  # Using "UserSession" name to avoid conflict with Admin::SessionsController
  actions :index, :show

  index do
    selectable_column
    id_column
    column :user do |user_session|
      link_to user_session.user.email_address, admin_user_path(user_session.user)
    end
    column :ip_address
    column :user_agent do |user_session|
      truncate(user_session.user_agent, length: 50)
    end
    column :suspicious_activity
    column :device_fingerprint
    column :created_at
    actions
  end

  filter :user
  filter :ip_address
  filter :suspicious_activity
  filter :device_fingerprint
  filter :created_at

  show do |user_session|
    attributes_table do
      row :id
      row :user do
        link_to user_session.user.email_address, admin_user_path(user_session.user)
      end
      row :ip_address
      row :user_agent
      row :suspicious_activity
      row :device_fingerprint
      row :created_at
      row :updated_at
    end
  end
end
