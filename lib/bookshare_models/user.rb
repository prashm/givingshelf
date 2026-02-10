# frozen_string_literal: true

# Temporary model for reading User data from Bookshare database
# Used during data migration from Bookshare to GivingShelf
module Bookshare
  class User < ActiveRecord::Base
    establish_connection :bookshare
    self.table_name = "users"

    # Read-only model for migration purposes
    # No validations or callbacks needed - just reading data
  end
end
