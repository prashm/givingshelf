# A message with request_transition_status records a status change on its request (the status it
# moved to), authored by whoever made the change. Its content is the optional note.
class AddRequestTransitionStatusToMessages < ActiveRecord::Migration[8.1]
  def change
    add_column :messages, :request_transition_status, :integer
  end
end
