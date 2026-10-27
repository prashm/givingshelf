# frozen_string_literal: true

require "test_helper"

class SessionCleanupJobTest < ActiveJob::TestCase
  def create_login_session(updated_at:)
    users(:one).sessions.create!(user_agent: "Test Agent", ip_address: "127.0.0.1").tap do |s|
      s.update_columns(updated_at: updated_at)
    end
  end

  def create_store_session(updated_at:)
    ActiveRecord::SessionStore::Session.create!(session_id: SecureRandom.hex(16), data: {}).tap do |s|
      s.update_columns(updated_at: updated_at)
    end
  end

  test "deletes idle login sessions and keeps active ones" do
    idle = create_login_session(updated_at: Session::IDLE_TIMEOUT.ago - 1.minute)
    active = create_login_session(updated_at: Session::IDLE_TIMEOUT.ago + 1.minute)

    SessionCleanupJob.perform_now

    assert_not Session.exists?(idle.id)
    assert Session.exists?(active.id)
  end

  test "deletes expired session-store rows and keeps recent ones" do
    expired = create_store_session(updated_at: Session::IDLE_TIMEOUT.ago - 1.minute)
    recent = create_store_session(updated_at: Session::IDLE_TIMEOUT.ago + 1.minute)

    SessionCleanupJob.perform_now

    assert_not ActiveRecord::SessionStore::Session.exists?(expired.id)
    assert ActiveRecord::SessionStore::Session.exists?(recent.id)
  end
end
