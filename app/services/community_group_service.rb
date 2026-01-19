class CommunityGroupService
  attr_accessor :group
  attr_reader :errors

  def initialize(group = nil)
    @group = group
    @errors = []
  end

  def create_group(admin_user, params)
    @group = CommunityGroup.new(params)

    ActiveRecord::Base.transaction do
      @group.save!
      @group.community_group_memberships.create!(
        user: admin_user,
        admin: true,
        auto_joined: false
      )
    end
  rescue => e
    @errors << e.message
    nil
  end

  def update_group(params)
    raise "group can't be blank" unless @group

    unless @group.update(params)
      @errors = @group.errors.full_messages
      return false
    end
    true
  rescue => e
    @errors << e.message
    false
  end

  def add_sub_group(name)
    raise "group can't be blank" unless @group

    sub_group = @group.sub_groups.build(name: name)
    unless sub_group.save
      @errors = sub_group.errors.full_messages
      return nil
    end
    sub_group
  rescue => e
    @errors << e.message
    nil
  end

  def remove_sub_group(sub_group_id)
    raise "sub_group is invalid" if sub_group_id.to_i <= 0
    raise "group can't be blank" unless @group
    sub_group = @group.sub_groups.find(sub_group_id)

    sub_group.destroy
    true
  rescue => e
    @errors << e.message
    false
  end

  def delete_group
    raise "group can't be blank" unless @group

    @group.destroy
    true
  rescue => e
    @errors << e.message
    false
  end

  def add_member(user, auto_joined: false, admin: false)
    return nil unless @group

    membership = @group.community_group_memberships.build(
      user: user,
      admin: admin,
      auto_joined: auto_joined
    )

    if membership.save
      membership
    else
      @errors = membership.errors.full_messages
      nil
    end
  end

  def remove_member(user)
    return false unless @group

    membership = @group.community_group_memberships.find_by(user: user)
    if membership
      membership.destroy
      true
    else
      @errors << "User is not a member of this group"
      false
    end
  rescue => e
    @errors << e.message
    false
  end

  def promote_to_admin(user)
    return false unless @group

    membership = @group.community_group_memberships.find_by(user: user)
    if membership
      membership.update(admin: true)
      true
    else
      @errors << "User is not a member of this group"
      false
    end
  rescue => e
    @errors << e.message
    false
  end

  def demote_from_admin(user)
    return false unless @group

    membership = @group.community_group_memberships.find_by(user: user)
    if membership
      membership.update(admin: false)
      true
    else
      @errors << "User is not a member of this group"
      false
    end
  rescue => e
    @errors << e.message
    false
  end

  def request_to_join(user, message: nil)
    raise "already a member" if @group.community_group_memberships.exists?(user: user)

    raise "already requested" if GroupMembershipRequest.requested.exists?(community_group: @group, requester: user, requester_type: "User")

    request = GroupMembershipRequest.create!(
      community_group: @group,
      requester: user,
      requester_type: "User",
      status: GroupMemberStatus::REQUESTED,
      message: message
    )

    CommunityGroupMailer.join_request(request).deliver_later
    request
  rescue => e
    @errors << e.message
    nil
  end

  def add_user_to_group_from_request(user, membership_request)
    group ||= membership_request.community_group
    raise "group can't be blank" unless group

    if group.community_group_memberships.exists?(user: user)
      membership_request.update!(
        status: GroupMemberStatus::ACCEPTED,
        accepted_at: Time.current,
        responded_at: Time.current
      ) if membership_request.requested?
      raise "already a member"
    end

    membership = nil
    current_status = membership_request.status

    ActiveRecord::Base.transaction do
      membership = CommunityGroupMembership.create!(
        community_group: group,
        user: user,
        admin: false,
        auto_joined: false,
        group_membership_request: membership_request
      )
      membership_request.update!(
        status: GroupMemberStatus::ACCEPTED,
        accepted_at: Time.current,
        responded_at: Time.current
      )
    end

    if current_status == GroupMemberStatus::INVITED
      CommunityGroupMailer.invite_accepted(group, user).deliver_later
    else
      CommunityGroupMailer.membership_accepted(group, user).deliver_later
    end
    membership
  rescue => e
    @errors << e.message
    nil
  end

  def invite_to_group(invitee_email:, inviter_admin:, message: nil)
    raise "Email is required" if invitee_email.blank?
    raise "User already a member" if group.members.exists?(email_address: invitee_email)

    request = GroupMembershipRequest.new(
      community_group: @group,
      requester: inviter_admin,
      requester_type: GroupMembershipRequest::ADMIN_REQUESTER_TYPE,
      email_address: invitee_email,
      message: message,
      status: GroupMemberStatus::INVITED
    )

    if request.save
      CommunityGroupMailer.invite(request).deliver_later
    else
      raise request.errors.full_messages.to_sentence
    end
    request
  rescue => e
    @errors << e.message
    nil
  end

  def group_filter(search_string: nil, public_only: false, short_name: nil, limit: nil)
    scope = CommunityGroup.left_joins(:community_group_memberships)
      .select("community_groups.*, COUNT(community_group_memberships.id) AS member_count")
      .group("community_groups.id")
      .order(Arel.sql("member_count DESC, community_groups.name ASC"))
    if search_string.present?
      scope = scope.where("community_groups.name ILIKE :search_string OR community_groups.short_name ILIKE :search_string", search_string: "%#{search_string}%")
    end
    if public_only
      scope = scope.where(public: true)
    end
    if short_name.present?
      scope = scope.where(short_name: short_name)
    end
    scope.limit(limit) if limit.present?
    scope
  end

  def get_group_by_short_name(short_name)
    group = group_filter(short_name: short_name, limit: 1).first
    return {} unless group
    self.class.group_map(group, include_sub_groups: true)
  end

  def public_groups(search_string: nil, limit: 10)
    groups = group_filter(search_string: search_string, public_only: true, limit: limit)
    groups.map { |g| self.class.group_map(g, member_count: g.attributes["member_count"].to_i) }
  end

  def get_memberships_for_group
    return nil unless self.group
    memberships = self.group.community_group_memberships.includes(:user)
    memberships.map { |m| self.class.membership_map(m) }
  end

  def membership_state_for(user)
    return "none" unless user && group

    if group.community_group_memberships.exists?(user: user)
      return "member"
    end

    if GroupMembershipRequest.requested.exists?(community_group: group, requester: user, requester_type: "User")
      return "requested"
    end

    if GroupMembershipRequest.invited.exists?(community_group: group, email_address: user.email_address)
      return "invited"
    end

    "none"
  end

  def self.group_map(group, include_sub_groups: false, member_count: group.community_group_memberships.count)
    result = {
      id: group.id,
      name: group.name,
      group_description: group.group_description,
      domain: group.domain,
      short_name: group.short_name,
      public: group.public,
      member_count: member_count,
      created_at: group.created_at,
      updated_at: group.updated_at
    }
    if include_sub_groups
      result[:sub_groups] = group.sub_groups.map { |sg| { id: sg.id, name: sg.name } }
    end
    result
  end

  def self.membership_map(membership)
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
