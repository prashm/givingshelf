module Group
  class AdminController < ApplicationController
    layout "admin"

    before_action :ensure_group_admin, unless: :group_admin_session_action?
    skip_before_action :require_authentication, if: :group_admin_session_action?

    def new
      redirect_to group_admin_index_path if authenticated? && Current.user.group_admin?
    end

    def create
      email = params[:email]&.strip&.downcase
      password = params[:password]

      if email.blank? || password.blank?
        flash.now[:alert] = "Email and password are required."
        render :new, status: :unprocessable_entity
        return
      end

      user = User.authenticate_by(email_address: email, password: password)

      if user && user.group_admin?
        start_new_session_for(user)
        redirect_to group_admin_index_path, notice: "Signed in successfully."
      else
        flash.now[:alert] = "Invalid email or password, or you don't have group admin access."
        render :new, status: :unprocessable_entity
      end
    end

    def destroy
      terminate_session
      redirect_to group_admin_login_path, notice: "Signed out successfully."
    end

    private

    def set_group
      group_id = params[:id] || params[:admin_id] || params[:group_id]
      @group = Current.user.admin_community_groups.find(group_id)
    rescue ActiveRecord::RecordNotFound
      redirect_to group_admin_index_path, alert: "Group not found."
    end

    def group_service
      @group_service ||= CommunityGroupService.new(@group)
    end

    def ensure_group_admin
      unless authenticated? && Current.user.group_admin?
        redirect_to group_admin_login_path, alert: "You must be a group admin to access this page."
      end
    end

    def before_authentication_url
      group_admin_login_path
    end

    def group_admin_session_action?
      self.class == Group::AdminController && %w[new create destroy].include?(action_name)
    end
  end
end
