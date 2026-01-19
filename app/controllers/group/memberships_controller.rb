module Group
  class MembershipsController < AdminController
    before_action :set_group
    before_action :set_membership, only: [ :promote_member, :demote_member, :revoke_membership ]

    # GET /group/admin/:id/memberships
    def index
      @tab = params[:tab].presence_in(%w[current requested invites]) || "current"
      @member_count = @group.community_group_memberships.size

      @current_memberships = @group.community_group_memberships.includes(:user).order(admin: :desc, created_at: :asc)
      @requested_requests = GroupMembershipRequest
        .requested
        .includes(:requester)
        .where(community_group: @group)
        .order(created_at: :desc)
      @invited_requests = GroupMembershipRequest
        .invited
        .where(community_group: @group)
        .order(created_at: :desc)
    end

    def promote_member
      @membership.update!(admin: true)
      redirect_to group_admin_memberships_path(@group, tab: "current"), notice: "Member promoted to admin."
    end

    def demote_member
      if @membership.admin? && @group.community_group_memberships.admins.count <= 1
        redirect_to group_admin_memberships_path(@group, tab: "current"), alert: "You can't remove the last admin from the group."
        return
      end

      @membership.update!(admin: false)
      redirect_to group_admin_memberships_path(@group, tab: "current"), notice: "Admin privileges revoked."
    end

    def revoke_membership
      if @membership.admin? && @group.community_group_memberships.admins.count <= 1
        redirect_to group_admin_memberships_path(@group, tab: "current"), alert: "You can't revoke membership for the last admin."
        return
      end

      @membership.destroy!
      redirect_to group_admin_memberships_path(@group, tab: "current"), notice: "Membership revoked."
    end

    def accept_membership_request
      request = GroupMembershipRequest.find(params[:request_id])
      error_message = ""
      error_message = "Request user not found." if request.requester.nil?
      error_message = "Invalid request." if !request.requested? || request.community_group_id != @group.id
      if error_message.blank?
        group_service.add_user_to_group_from_request(request.requester, request)
        error_message = group_service.errors.join(", ") if group_service.errors.present?
      end
      if error_message.present?
        redirect_to group_admin_memberships_path(@group, tab: "requested"), alert: error_message
      else
        redirect_to group_admin_memberships_path(@group, tab: "requested"), notice: "Request accepted and membership created."
      end
    end

    def reject_membership_request
      request = GroupMembershipRequest.find(params[:request_id])
      error_message = ""
      error_message = "Invalid request." if !request.requested? || request.community_group_id != @group.id
      if error_message.blank?
        request.reject
        error_message = request.errors.full_messages.to_sentence if request.errors.present?
      end
      if error_message.present?
        redirect_to group_admin_memberships_path(@group, tab: "requested"), alert: error_message
      else
        redirect_to group_admin_memberships_path(@group, tab: "requested"), notice: "Request rejected."
      end
    end

    def create_invite
      group_service.invite_to_group(
        invitee_email: params[:email_address].to_s.strip.downcase,
        inviter_admin: Current.user,
        message: params[:message]
      )
      if group_service.errors.present?
        redirect_to group_admin_memberships_path(@group, tab: "invites"), alert: group_service.errors.join(", ")
      else
        redirect_to group_admin_memberships_path(@group, tab: "invites"), notice: "Invitation created."
      end
    end

    def revoke_invite
      request = GroupMembershipRequest.find(params[:request_id])
      error_message = ""
      error_message = "Invalid invite." if !request.invited? || request.community_group_id != @group.id
      if error_message.blank?
        request.reject
        error_message = request.errors.full_messages.to_sentence if request.errors.present?
      end
      if error_message.present?
        redirect_to group_admin_memberships_path(@group, tab: "invites"), alert: error_message
      else
        redirect_to group_admin_memberships_path(@group, tab: "invites"), notice: "Invite revoked."
      end
    end

    private

    def set_membership
      @membership = @group.community_group_memberships.find(params[:membership_id])
    rescue ActiveRecord::RecordNotFound
      redirect_to group_admin_memberships_path(@group, tab: "current"), alert: "Membership not found."
    end
  end
end

