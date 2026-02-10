# frozen_string_literal: true

# Temporary model for reading ActiveStorage Attachment data from Bookshare database
# Used during data migration from Bookshare to GivingShelf
module Bookshare
  class ActiveStorageAttachment < ActiveRecord::Base
    establish_connection :bookshare
    self.table_name = "active_storage_attachments"

    # Read-only model for migration purposes
  end
end
