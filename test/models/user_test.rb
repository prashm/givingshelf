require "test_helper"
require "minitest/spec"

class UserTest < ActiveSupport::TestCase
  extend Minitest::Spec::DSL

  # Helper method similar to RSpec's let - creates a user with default attributes
  def user_with_context(password, **overrides)
    defaults = {
      email_address: "john@example.com",
      first_name: "John",
      last_name: "Smith",
      password: password,
      password_confirmation: password
    }
    User.new(defaults.merge(overrides))
  end

  describe "password strength validation" do
    it "rejects weak passwords" do
      user = user_with_context("password123")
      assert_not user.valid?
      assert_includes user.errors[:password].join(" "), "too weak"
    end

    it "rejects common passwords" do
      user = user_with_context("qwerty123")
      assert_not user.valid?
      assert_includes user.errors[:password].join(" "), "too weak"
    end

    it "accepts strong passwords" do
      user = user_with_context("Tr0ng!P@ssw0rd#2024")
      # Should not have password strength errors (may have other validation errors)
      password_errors = user.errors[:password].select { |e| e.include?("too weak") }
      assert_empty password_errors
    end

    it "checks against user context" do
      user = user_with_context("john1234")
      assert_not user.valid?
      assert_includes user.errors[:password].join(" "), "too weak"
    end

    it "skips when password length is less than 8" do
      user = user_with_context("weak")
      # Should fail on length validation, not strength validation
      assert_not user.valid?
      password_errors = user.errors[:password]
      # Should have length error
      assert password_errors.any? { |e| e.include?("too short") || e.include?("minimum") }, "Expected length validation error, got: #{password_errors.inspect}"
      # Should NOT have strength error (strength validation should be skipped)
      assert_not password_errors.any? { |e| e.include?("too weak") }, "Strength validation should not run for passwords < 8 characters"
    end

    it "runs when password length is 8 or more" do
      user = user_with_context("password") # 8 characters but weak
      assert_not user.valid?
      # Should have strength error since it's 8+ characters
      assert user.errors[:password].any? { |e| e.include?("too weak") }
    end

    it "allows moderately strong passwords" do
      user = user_with_context("MyP@ssw0rd")
      # Should not have password strength errors
      password_errors = user.errors[:password].select { |e| e.include?("too weak") }
      assert_empty password_errors
    end
  end
end
