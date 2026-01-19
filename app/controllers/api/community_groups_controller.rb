class Api::CommunityGroupsController < ApplicationController
  before_action :require_authentication, only: [
    :request_to_join,
    :my_groups,
    :my_group_requests,
    :my_group_invites,
    :accept_invite,
    :leave_group,
    :cancel_join_request
  ]
  before_action :set_group, only: [ :show, :request_to_join ]

  def by_short_name
    group_map = group_service.get_group_by_short_name(params[:short_name])
    if group_map.present?
      render json: group_map
    else
      render json: { error: "Group not found" }, status: :not_found
    end
  end

  # GET /api/community_groups?q=...
  # Public-only search for group discovery (used by My Groups autocomplete).
  def index
    render json: group_service.public_groups(search_string: params[:q], limit: 10)
  end

  # GET /api/community_groups/:id
  # Group details for discovery/join flow.
  def show
    membership_state = group_service.membership_state_for(authenticated? ? Current.user : nil)

    render json: CommunityGroupService.group_map(@group).merge(
      membership_state: membership_state
    )
  end

  def request_to_join
    return render json: { error: "Not found" }, status: :not_found unless @group.public?

    request = group_service.request_to_join(Current.user, message: params[:message])
    if request.nil?
      render json: { error: group_service.errors.join(", ") }, status: :unprocessable_entity
    else
      render json: { status: "requested", request_id: request.id }, status: :created
    end
  end

  def my_groups
    render json: user_service.my_groups
  end

  def my_group_requests
    render json: user_service.my_group_requests
  end

  def my_group_invites
    render json: user_service.my_group_invites
  end

  def accept_invite
    request = GroupMembershipRequest.find(params[:id])
    if !request.invited? || request.email_address != Current.user.email_address
      return render json: { error: "Not authorized" }, status: :forbidden
    end

    membership = group_service.add_user_to_group_from_request(Current.user, request)
    if membership
      render json: { status: "accepted", membership_id: membership.id }, status: :ok
    else
      render json: { error: group_service.errors.join(", ") }, status: :unprocessable_entity
    end
  end

  def leave_group
    membership = Current.user.community_group_memberships.find(params[:id])
    membership.destroy!
    render json: { status: "left" }, status: :ok
  end

  def cancel_join_request
    request = GroupMembershipRequest.find(params[:id])
    if !request.requested? ||
      request.requester_id != Current.user.id ||
      request.requester_type != GroupMembershipRequest::USER_REQUESTER_TYPE
      return render json: { error: "Not authorized" }, status: :forbidden
    end

    request.destroy!
    render json: { status: "cancelled" }, status: :ok
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

  def user_service
    @user_service ||= UserService.new(Current.user)
  end
end
