require "test_helper"

class SessionIdleTimeoutTest < ActionDispatch::IntegrationTest
  test "session idle for less than the idle timeout stays valid" do
    session_record = sign_in_as(users(:one))
    session_record.update_columns(updated_at: Session::IDLE_TIMEOUT.ago + 1.minute)

    get profile_api_users_url
    assert_response :success
    assert Session.exists?(session_record.id)
  end

  test "session idle for more than the idle timeout is rejected and destroyed" do
    session_record = sign_in_as(users(:one))
    session_record.update_columns(updated_at: Session::IDLE_TIMEOUT.ago - 1.minute)

    get profile_api_users_url
    assert_response :unauthorized
    assert_not Session.exists?(session_record.id)
  end

  test "activity bumps last-activity time once the touch interval has passed" do
    session_record = sign_in_as(users(:one))
    session_record.update_columns(updated_at: Session::ACTIVITY_TOUCH_INTERVAL.ago - 1.minute)

    get profile_api_users_url
    assert_response :success
    assert_in_delta Time.current, session_record.reload.updated_at, 1.minute
  end

  test "activity within the touch interval does not write to the session row" do
    session_record = sign_in_as(users(:one))
    recent = 1.minute.ago
    session_record.update_columns(updated_at: recent)

    get profile_api_users_url
    assert_response :success
    assert_in_delta recent, session_record.reload.updated_at, 1.second
  end
end
