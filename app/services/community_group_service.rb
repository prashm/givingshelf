class CommunityGroupService
  attr_accessor :group
  attr_reader :errors

  def initialize(group = nil)
    @group = group
    @errors = []
  end

  def create_group(admin_user, params)
    @group = CommunityGroup.new(params)

    if @group.save
      # Add admin_user as admin member
      @group.community_group_memberships.create!(
        user: admin_user,
        admin: true,
        auto_joined: false
      )
      @group
    else
      @errors = @group.errors.full_messages
      nil
    end
  rescue => e
    @errors << e.message
    nil
  end

  def update_group(params)
    return nil unless @group

    if @group.update(params)
      @group
    else
      @errors = @group.errors.full_messages
      nil
    end
  end

  def add_sub_group(name)
    return nil unless @group

    sub_group = @group.sub_groups.build(name: name)
    if sub_group.save
      sub_group
    else
      @errors = sub_group.errors.full_messages
      nil
    end
  end

  def remove_sub_group(sub_group)
    return false unless @group && sub_group.community_group == @group

    sub_group.destroy
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

  def self.find_by_short_name(short_name)
    CommunityGroup.by_short_name(short_name).first
  end
end
