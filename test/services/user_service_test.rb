require "test_helper"
require "minitest/spec"

class UserServiceTest < ActiveSupport::TestCase
  extend Minitest::Spec::DSL

  def setup
    @user = users(:one)
    @service = UserService.new(@user)
  end

  describe "#find_or_create_user_by_email" do
    it "returns nil and sets error for invalid email" do
      service = UserService.new
      result = service.find_or_create_user_by_email("not-an-email")
      assert_nil result
      assert_includes service.errors.join(" "), "Invalid email address"
    end

    it "returns existing user when found" do
      service = UserService.new
      result = service.find_or_create_user_by_email(users(:one).email_address)
      assert_equal users(:one).id, result.id
      assert_empty service.errors
    end

    it "creates a new user with validate: false when not found" do
      email = "new_user_#{SecureRandom.hex(4)}@example.com"
      service = UserService.new
      assert_difference "User.count", 1 do
        result = service.find_or_create_user_by_email(email)
        assert result.persisted?
        assert_equal email, result.email_address
      end
      assert_empty service.errors
    end
  end

  describe "#verify_otp" do
    it "returns nil and sets error when email or otp is blank" do
      service = UserService.new
      result = service.verify_otp("", "")
      assert_nil result
      assert_includes service.errors.join(" "), "Email and OTP code are required"
    end

    it "returns nil and sets error when user not found" do
      service = UserService.new
      result = service.verify_otp("missing_#{SecureRandom.hex(4)}@example.com", "123456")
      assert_nil result
      assert_includes service.errors.join(" "), "User not found"
    end

    it "returns nil and sets error when otp expired" do
      service = UserService.new
      u = users(:one)
      u.update!(otp_sent_at: 10.minutes.ago, otp_secret: "ABCDEF")
      User.stub(:find_by, u) do
        u.stub(:otp_expired?, true) do
          result = service.verify_otp(u.email_address, "123456")
          assert_nil result
          assert_includes service.errors.join(" "), "OTP code has expired"
        end
      end
    end

    it "delegates to user.verify_otp when not expired" do
      service = UserService.new
      u = users(:one)
      u.update!(otp_sent_at: Time.current, otp_secret: "ABCDEF")
      User.stub(:find_by, u) do
        u.stub(:otp_expired?, false) do
          u.stub(:verify_otp, true) do
            result = service.verify_otp(u.email_address, "123456")
            assert_equal true, result
            assert_empty service.errors
          end
        end
      end
    end
  end

  describe "#update_user" do
    it "updates user and ensures zipcode group membership/subgroup" do
      zip_group = CommunityGroup.find_or_create_zipcode_group!
      # Ensure a clean slate
      CommunityGroupMembership.where(user: @user, community_group: zip_group).delete_all

      ok = @service.update_user({ zip_code: "99999" })
      assert ok, @service.errors.to_sentence

      @user.reload
      assert_equal "99999", @user.zip_code
      membership = CommunityGroupMembership.find_by!(user: @user, community_group: zip_group)
      sub_group = SubGroup.find_by!(community_group: zip_group, name: "99999")
      assert_equal sub_group.id, membership.sub_group_id
    end

    it "sets address_verified via AddressVerificationService when address fields are present" do
      # Avoid triggering User#geocode_coordinates (which also uses AddressVerificationService).
      @user.update!(latitude: 0.0, longitude: 0.0)

      fake_avs = Object.new
      def fake_avs.verify(_address_params, _zip) = true

      AddressVerificationService.stub(:new, fake_avs) do
        ok = @service.update_user({
          street_address: "1 Main St",
          city: "Town",
          state: "CA",
          zip_code: @user.zip_code
        })
        assert ok, @service.errors.to_sentence
      end

      assert_equal true, @user.reload.address_verified?
    end

    it "rolls back user update if zipcode membership step fails" do
      original_first_name = @user.first_name

      CommunityGroup.stub(:find_or_create_zipcode_group!, -> { raise "boom" }) do
        ok = @service.update_user({ first_name: "ShouldNotPersist", zip_code: "99999" })
        assert_not ok
        assert_includes @service.errors.join(" "), "boom"
      end

      assert_equal original_first_name, @user.reload.first_name
    end
  end

  describe "#my_groups" do
    it "returns mapped memberships including sub_groups and selected sub_group" do
      group = community_groups(:one)
      membership = CommunityGroupMembership.find_by!(user: users(:one), community_group: group)
      membership.update!(sub_group_id: sub_groups(:one).id)

      result = UserService.new(users(:one)).my_groups
      assert_equal users(:one).community_group_memberships.count, result.length

      row = result.find { |g| g[:id] == group.id }
      assert row
      assert row[:membership_id]
      assert_equal true, row[:admin] # fixture user(:one) is admin of group one
      assert row.key?(:sub_groups)
      assert row[:sub_group]
      assert_equal sub_groups(:one).id, row[:sub_group][:id]
    end
  end

  describe "#my_group_requests" do
    it "returns only requested join requests for current user" do
      user = users(:one)
      group = community_groups(:two)

      mine = GroupMembershipRequest.create!(
        community_group: group,
        requester: user,
        requester_type: GroupMembershipRequest::USER_REQUESTER_TYPE,
        status: GroupMemberStatus::REQUESTED,
        message: "please"
      )
      GroupMembershipRequest.create!(
        community_group: group,
        requester: users(:two),
        requester_type: GroupMembershipRequest::USER_REQUESTER_TYPE,
        status: GroupMemberStatus::REQUESTED
      )
      GroupMembershipRequest.create!(
        community_group: group,
        requester: users(:two),
        requester_type: GroupMembershipRequest::ADMIN_REQUESTER_TYPE,
        status: GroupMemberStatus::INVITED,
        email_address: user.email_address
      )

      result = UserService.new(user).my_group_requests
      assert_equal 1, result.length
      assert_equal mine.id, result.first[:id]
      assert_equal "Requested", result.first[:status_display]
      assert result.first[:community_group]
    end
  end

  describe "#my_group_invites" do
    it "returns only invites matching user's email and includes inviter" do
      user = users(:one)
      group = community_groups(:two)

      mine = GroupMembershipRequest.create!(
        community_group: group,
        requester: users(:two),
        requester_type: GroupMembershipRequest::ADMIN_REQUESTER_TYPE,
        status: GroupMemberStatus::INVITED,
        email_address: user.email_address,
        message: "join us"
      )
      GroupMembershipRequest.create!(
        community_group: group,
        requester: users(:two),
        requester_type: GroupMembershipRequest::ADMIN_REQUESTER_TYPE,
        status: GroupMemberStatus::INVITED,
        email_address: "someone_else@example.com"
      )

      result = UserService.new(user).my_group_invites
      assert_equal 1, result.length
      assert_equal mine.id, result.first[:id]
      assert result.first[:inviter]
      assert_equal users(:two).id, result.first[:inviter][:id]
    end
  end
end

