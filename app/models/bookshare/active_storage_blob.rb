# frozen_string_literal: true

# Temporary model for reading ActiveStorage Blob data from Bookshare database
# Used during data migration from Bookshare to GivingShelf
module Bookshare
  class ActiveStorageBlob < ActiveRecord::Base
    establish_connection :bookshare
    self.table_name = "active_storage_blobs"

    # Read-only model for migration purposes
  end
end
