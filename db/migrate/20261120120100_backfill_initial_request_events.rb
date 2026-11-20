# Moves each request's message into its thread as the initial PENDING event, authored by the
# requester at the request's created_at. Safe to run again: requests that already have a PENDING
# event are skipped. The item_requests.message column is dropped in a later deploy, which repeats
# this backfill first to catch requests made by the old code while this one was deploying.
class BackfillInitialRequestEvents < ActiveRecord::Migration[8.1]
  PENDING_STATUS = 0

  def self.backfill_sql
    <<~SQL.squish
      INSERT INTO messages (item_request_id, user_id, content, request_transition_status, created_at, updated_at)
      SELECT item_requests.id, item_requests.requester_id, NULLIF(BTRIM(item_requests.message), ''), #{PENDING_STATUS},
             item_requests.created_at, item_requests.created_at
      FROM item_requests
      WHERE NOT EXISTS (
        SELECT 1 FROM messages
        WHERE messages.item_request_id = item_requests.id
          AND messages.request_transition_status = #{PENDING_STATUS}
      )
    SQL
  end

  def up
    execute self.class.backfill_sql
  end

  def down
    # The events can't be told apart from ones written later, and item_requests.message is still
    # there, so there's nothing to undo.
  end
end
