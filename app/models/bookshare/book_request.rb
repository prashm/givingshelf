# frozen_string_literal: true

# Temporary model for reading BookRequest data from Bookshare database
# Used during data migration from Bookshare to GivingShelf
module Bookshare
  class BookRequest < ActiveRecord::Base
    establish_connection :bookshare
    self.table_name = "book_requests"

    # Read-only model for migration purposes
    # No validations or callbacks needed - just reading data
  end
end
