# frozen_string_literal: true

# Temporary model for reading GroupBookAvailability data from Bookshare database
# Used during data migration from Bookshare to GivingShelf
module Bookshare
  class GroupBookAvailability < ActiveRecord::Base
    establish_connection :bookshare
    self.table_name = "group_book_availabilities"

    # Read-only model for migration purposes
    # No validations or callbacks needed - just reading data
  end
end
