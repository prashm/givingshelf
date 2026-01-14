class Api::CommunityGroupsController < ApplicationController
  before_action :require_authentication, only: [ :memberships ]
  before_action :set_group, only: [ :memberships ]

  def by_short_name
    group_json = group_service.get_group_by_short_name(params[:short_name])
    if group_json.present?
      render json: group_json
    else
      render json: { error: "Group not found" }, status: :not_found
    end
  end

  def memberships
    # Only admins can view memberships
    unless @group.admin?(Current.user)
      render json: { error: "Not authorized" }, status: :forbidden
      return
    end

    memberships_json = group_service.get_memberships_for_group
    if memberships_json.present?
      render json: memberships_json
    else
      render json: { error: "Memberships not found" }, status: :not_found
    end
  end

  private

  def set_group
    @group = CommunityGroup.find(params[:id])
  rescue ActiveRecord::RecordNotFound
    render json: { error: "Group not found" }, status: :not_found
  end

  def group_service
    @group_service ||= CommunityGroupService.new(@group)
  end
end
