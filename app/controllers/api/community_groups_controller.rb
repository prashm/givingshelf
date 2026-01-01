class Api::CommunityGroupsController < ApplicationController
  before_action :require_authentication, only: [:memberships]
  before_action :set_group, only: [:show, :memberships]

  def show
    render json: group_json(@group)
  end

  def by_short_name
    @group = CommunityGroup.find_by(short_name: params[:short_name])
    if @group
      render json: group_json(@group)
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

    memberships = @group.community_group_memberships.includes(:user)
    render json: {
      group: group_json(@group),
      memberships: memberships.map { |m| membership_json(m) }
    }
  end

  private

  def set_group
    @group = CommunityGroup.find(params[:id])
  rescue ActiveRecord::RecordNotFound
    render json: { error: "Group not found" }, status: :not_found
  end

  def group_json(group)
    {
      id: group.id,
      name: group.name,
      group_type: group.group_type,
      domain: group.domain,
      short_name: group.short_name,
      sub_groups: group.sub_groups.map { |sg| { id: sg.id, name: sg.name } },
      created_at: group.created_at,
      updated_at: group.updated_at
    }
  end

  def membership_json(membership)
    {
      id: membership.id,
      user: {
        id: membership.user.id,
        email_address: membership.user.email_address,
        display_name: membership.user.display_name,
        full_name: membership.user.full_name
      },
      admin: membership.admin,
      auto_joined: membership.auto_joined,
      created_at: membership.created_at
    }
  end
end

