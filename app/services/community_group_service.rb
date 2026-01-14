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

  def get_group_by_short_name(short_name)
    group = CommunityGroup.by_short_name(short_name).first
    return {} unless group
    self.class.group_json(group)
  end

  def get_memberships_for_group
    return nil unless self.group
    memberships = self.group.community_group_memberships.includes(:user)
    memberships.map { |m| self.class.membership_json(m) }
  end

  def self.group_json(group)
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

  def self.membership_json(membership)
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
