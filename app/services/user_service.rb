class UserService
  attr_accessor :user
  attr_reader :errors, :new_user

  def initialize(user = nil)
    @user = user
    @errors = []
  end

  def find_or_create_user_by_email(email)
    if email.blank? || !email.match?(URI::MailTo::EMAIL_REGEXP)
      @errors << "Invalid email address"
      return
    end

    user = User.find_by(email_address: email)
    self.user = user

    unless user
      # New user - create user
      password = SecureRandom.hex(16) # Temporary password for passwordless flow
      user = User.new(
        email_address: email,
        password: password,
        password_confirmation: password
      )

      # Skip validations for incomplete profile
      user.save!(validate: false)
      # Note: auto_join_groups_by_domain! is called via after_create callback
    end

    user
  rescue => e
    # Perhaps user email already exists?
    @errors << e.message
    nil
  end

  def verify_otp(email, otp_code)
    raise "Email and OTP code are required" if email.blank? || otp_code.blank?

    user = User.find_by(email_address: email)
    self.user = user

    @errors << "User not found" unless user

    raise "OTP code has expired. Please request a new one." if user.otp_expired?

    user.verify_otp(otp_code)
  rescue => e
    @errors << e.message
    nil
  end

  def update_user(user_params)
    user_params = user_params.with_indifferent_access
    # Verify address if address fields are provided
    if user_params[:street_address].present? && user_params[:city].present? && user_params[:state].present?
      address_params = {
        street_address: user_params[:street_address],
        city: user_params[:city],
        state: user_params[:state],
        zip_code: user_params[:zip_code] || self.user.zip_code
      }
      user_params[:address_verified] = AddressVerificationService.new.verify(address_params, address_params[:zip_code])
    end
    user.update!(user_params)
    true
  rescue => e
    @errors << e.message
    false
  end

  def my_groups
    memberships = user.community_group_memberships
      .includes(:sub_group, community_group: :sub_groups).order(created_at: :desc)

    admin_counts = CommunityGroupMembership.admins
      .where(community_group_id: memberships.map(&:community_group_id))
      .group(:community_group_id)
      .count

    memberships.map { |m|
      CommunityGroupService.group_map(m.community_group).merge(
        membership_id: m.id,
        joined_at: m.created_at,
        admin: m.admin,
        sole_admin: m.admin && admin_counts[m.community_group_id].to_i == 1,
        sub_groups: m.community_group.sub_groups.map { |sg| { id: sg.id, name: sg.name } },
        sub_group: m.sub_group ? { id: m.sub_group.id, name: m.sub_group.name } : nil
      )
    }
  end

  def my_group_requests
    requests = GroupMembershipRequest
      .requested
      .includes(:community_group)
      .where(requester: user, requester_type: GroupMembershipRequest::USER_REQUESTER_TYPE)
      .order(created_at: :desc)

    requests.map { |r| group_membership_request_map(r) }
  end

  def my_group_invites
    requests = GroupMembershipRequest
      .invited
      .includes(:community_group, :requester)
      .where(email_address: user.email_address)
      .order(created_at: :desc)

    requests.map { |r| group_membership_request_map(r, include_inviter: true) }
  end

  private

  def group_membership_request_map(request, include_inviter: false)
    result = {
      id: request.id,
      status: request.status,
      status_display: request.display_status,
      message: request.message,
      created_at: request.created_at,
      community_group: CommunityGroupService.group_map(request.community_group)
    }
    if include_inviter
      result[:inviter] = {
        id: request.requester.id,
        display_name: request.requester.display_name
      }
    end
    result
  end
end
