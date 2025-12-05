class Session < ApplicationRecord
  self.table_name = "user_sessions"
  belongs_to :user
end
