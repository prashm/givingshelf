module Group
  class GroupsController < AdminController
    before_action :set_group, only: [ :show, :update, :destroy, :create_sub_group, :destroy_sub_group ]

    def index
      @groups = Current.user.admin_community_groups.includes(:sub_groups, :community_group_memberships).order(created_at: :desc)
    end

    def show
    end

    def create
      @group = group_service.create_group(Current.user, group_params)

      if @group
        redirect_to group_admin_path(@group.id), notice: "Group created successfully."
      else
        redirect_to group_admin_index_path, alert: group_service.errors.join(", ")
      end
    end

    def update
      if group_service.update_group(group_params)
        redirect_to group_admin_path(@group.id), notice: "Group updated successfully."
      else
        flash.now[:alert] = group_service.errors.join(", ")
        render :show, status: :unprocessable_entity
      end
    end

    def destroy
      if group_service.delete_group
        redirect_to group_admin_index_path, notice: "Group deleted successfully."
      else
        flash[:alert] = group_service.errors.join(", ")
        redirect_to group_admin_index_path
      end
    end

    def create_sub_group
      if group_service.add_sub_group(params[:name])
        redirect_to group_admin_path(@group.id), notice: "Sub group added successfully."
      else
        flash[:alert] = group_service.errors.join(", ")
        redirect_to group_admin_path(@group.id)
      end
    end

    def destroy_sub_group
      if group_service.remove_sub_group(params[:sub_group_id].to_i)
        redirect_to group_admin_path(@group.id), notice: "Sub group removed successfully."
      else
        flash[:alert] = group_service.errors.join(", ")
        redirect_to group_admin_path(@group.id)
      end
    end

    private

    def group_params
      params.require(:community_group).permit(:name, :group_description, :domain, :short_name, :public).to_h.with_indifferent_access
    rescue ActionController::ParameterMissing
      # Handle case where params might not be nested
      params.permit(:name, :group_description, :domain, :short_name, :public).to_h.with_indifferent_access
    end
  end
end
