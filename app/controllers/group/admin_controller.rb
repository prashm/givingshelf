module Group
  class AdminController < ApplicationController
    layout "admin"

    before_action :ensure_group_admin, except: [ :new, :create, :destroy ]
    skip_before_action :require_authentication, only: [ :new, :create, :destroy ]
    before_action :set_group, only: [ :show, :update, :create_sub_group, :destroy_sub_group ]

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

    def index
      @groups = Current.user.admin_community_groups.includes(:sub_groups).order(created_at: :desc)
    end

    def show
    end

    def create_group
      @group = group_service.create_group(Current.user, group_params)

      if @group
        redirect_to group_admin_group_path(@group.id), notice: "Group created successfully."
      else
        redirect_to group_admin_index_path, alert: group_service.errors.join(", ")
      end
    end

    def update
      if group_service.update_group(group_params)
        redirect_to group_admin_group_path(@group.id), notice: "Group updated successfully."
      else
        flash.now[:alert] = group_service.errors.join(", ")
        render :show, status: :unprocessable_entity
      end
    end

    def create_sub_group
      if group_service.add_sub_group(params[:name])
        redirect_to group_admin_group_path(@group.id), notice: "Sub group added successfully."
      else
        flash[:alert] = group_service.errors.join(", ")
        redirect_to group_admin_group_path(@group.id)
      end
    end

    def destroy_sub_group
      if group_service.remove_sub_group(params[:sub_group_id].to_i)
        redirect_to group_admin_group_path(@group.id), notice: "Sub group removed successfully."
      else
        flash[:alert] = group_service.errors.join(", ")
        redirect_to group_admin_group_path(@group.id)
      end
    end

    def destroy
      terminate_session
      redirect_to group_admin_login_path, notice: "Signed out successfully."
    end

    private

    def set_group
      @group = Current.user.admin_community_groups.find(params[:id])
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

    def group_params
      params.require(:community_group).permit(:name, :group_type, :domain, :short_name).to_h.with_indifferent_access
    rescue ActionController::ParameterMissing
      # Handle case where params might not be nested
      params.permit(:name, :group_type, :domain, :short_name).to_h.with_indifferent_access
    end

    def before_authentication_url
      group_admin_login_path
    end
  end
end
