class CommunityGroupMailer < ApplicationMailer
  def join_request(group_membership_request)
    @request = group_membership_request
    @group = @request.community_group
    @requester = @request.requester
    @message = @request.message

    recipients = @group.admins.pluck(:email_address)
    return if recipients.blank?

    @manage_url = group_admin_group_memberships_url(@group)
    @group_page_url = group_page_url(short_name: @group.short_name)

    mail(
      to: recipients,
      subject: "Join request for #{@group.name}"
    )
  end

  def invite(group_membership_request)
    @request = group_membership_request
    @group = @request.community_group
    @inviter = @request.requester
    @invitee_email = @request.email_address
    @message = @request.message
    @member_count = @group.community_group_memberships.count

    @my_groups_url = "#{root_url}my-groups?tab=invites"
    @group_page_url = group_page_url(short_name: @group.short_name)

    mail(
      to: @invitee_email,
      subject: "You're invited to join #{@group.name}"
    )
  end

  def membership_accepted(group, user)
    @group = group
    @user = user
    @group_page_url = group_page_url(short_name: @group.short_name)

    mail(
      to: @user.email_address,
      subject: "You're now a member of #{@group.name}"
    )
  end

  def invite_accepted(group, user)
    @group = group
    @user = user
    @manage_url = group_admin_group_memberships_url(@group)
    @group_page_url = group_page_url(short_name: @group.short_name)

    recipients = @group.admins.pluck(:email_address)
    return if recipients.blank?

    mail(
      to: recipients,
      subject: "#{@user.display_name} accepted the invite to #{@group.name}"
    )
  end
end
