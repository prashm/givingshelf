# frozen_string_literal: true

# Deletes login sessions (user_sessions) and Rails session-store rows (sessions)
# that have been idle longer than their timeouts. Idle login sessions are already
# rejected at request time by Authentication; this just keeps both tables from growing.
class SessionCleanupJob < ApplicationJob
  queue_as :default

  def perform
    login_count = Session.idle_expired.delete_all
    store_count = ActiveRecord::SessionStore::Session
      .where(updated_at: ...Rails.application.config.session_options[:expire_after].ago)
      .delete_all

    Rails.logger.info(
      "[SessionCleanupJob] Deleted #{login_count} idle user_sessions and #{store_count} expired sessions rows"
    )
  end
end
