# frozen_string_literal: true

# One-time migration script to migrate data from Bookshare DB to GivingShelf DB (STI structure).
#
# Run from Rails console (recommended):
#
#   load Rails.root.join("lib/onetime_scripts/migrate_from_bookshare_to_items.rb")
#   OnetimeScripts::MigrateFromBookshareToItems.run!
#
# Optional:
#   OnetimeScripts::MigrateFromBookshareToItems.run!(dry_run: true)
#
module OnetimeScripts
  class MigrateFromBookshareToItems
    def self.run!(dry_run: false)
      new(dry_run: dry_run).run!
    end

    def initialize(dry_run:)
      @dry_run = dry_run
      @user_map = {} # bookshare_user_id => givingshelf_user_id
      @group_map = {} # bookshare_group_id => givingshelf_group_id
      @book_map = {} # bookshare_book_id => givingshelf_item_id
      @request_map = {} # bookshare_request_id => givingshelf_request_id
    end

    def run!
      started_at = Time.current
      puts ""
      puts "== MigrateFromBookshareToItems starting =="
      puts "Time: #{started_at}"
      puts "dry_run=#{@dry_run}"

      migrate_users!
      migrate_community_groups!
      migrate_books_to_items!
      migrate_group_book_availabilities!
      migrate_book_requests!
      migrate_messages!

      puts ""
      puts "== Migration Summary =="
      puts "Users migrated: #{@user_map.length}"
      puts "Groups migrated: #{@group_map.length}"
      puts "Books migrated: #{@book_map.length}"
      puts "Requests migrated: #{@request_map.length}"
      puts "== Done in #{(Time.current - started_at).round(2)}s =="
      true
    rescue => e
      puts "!! FAILED: #{e.class}: #{e.message}"
      puts e.backtrace.first(20).join("\n")
      raise
    end

    private

    def migrate_users!
      puts ""
      puts "-- Migrating users from Bookshare to GivingShelf"

      bookshare_users = Bookshare::User.all.to_a
      puts "Found #{bookshare_users.length} users in Bookshare DB"

      bookshare_users.each_with_index do |bs_user, idx|
        puts "  [#{idx + 1}/#{bookshare_users.length}] Migrating user: #{bs_user.email_address}" if (idx % 100).zero?

        if @dry_run
          @user_map[bs_user.id] = bs_user.id # Use same ID for dry run
          next
        end

        gs_user = User.find_or_initialize_by(email_address: bs_user.email_address)
        gs_user.assign_attributes(
          first_name: bs_user.first_name,
          last_name: bs_user.last_name,
          zip_code: bs_user.zip_code,
          phone: bs_user.phone,
          street_address: bs_user.street_address,
          city: bs_user.city,
          state: bs_user.state,
          latitude: bs_user.latitude,
          longitude: bs_user.longitude,
          verified: bs_user.verified,
          address_verified: bs_user.address_verified || false,
          trust_score: bs_user.trust_score || 0,
          admin: bs_user.admin || false,
          group_admin: bs_user.group_admin || false,
          password_digest: bs_user.password_digest,
          otp_secret: bs_user.otp_secret,
          otp_sent_at: bs_user.otp_sent_at,
          otp_attempts: bs_user.otp_attempts || 0
        )

        if gs_user.new_record?
          gs_user.created_at = bs_user.created_at
        end
        gs_user.updated_at = bs_user.updated_at

        gs_user.save!(validate: false) # Skip validations for migration
        @user_map[bs_user.id] = gs_user.id
      end

      puts "-- User migration complete"
    end

    def migrate_community_groups!
      puts ""
      puts "-- Migrating community groups from Bookshare to GivingShelf"

      bookshare_groups = Bookshare::CommunityGroup.all.to_a
      puts "Found #{bookshare_groups.length} groups in Bookshare DB"

      bookshare_groups.each_with_index do |bs_group, idx|
        puts "  [#{idx + 1}/#{bookshare_groups.length}] Migrating group: #{bs_group.name}" if (idx % 50).zero?

        if @dry_run
          @group_map[bs_group.id] = bs_group.id
          next
        end

        gs_group = CommunityGroup.find_or_initialize_by(short_name: bs_group.short_name)
        gs_group.assign_attributes(
          name: bs_group.name,
          domain: bs_group.domain,
          group_description: bs_group.group_description,
          public: bs_group.public || false
        )

        if gs_group.new_record?
          gs_group.created_at = bs_group.created_at
        end
        gs_group.updated_at = bs_group.updated_at

        gs_group.save!(validate: false)
        @group_map[bs_group.id] = gs_group.id

        # Migrate memberships for this group
        migrate_group_memberships!(bs_group.id, gs_group.id)
      end

      puts "-- Community group migration complete"
    end

    def migrate_group_memberships!(bs_group_id, gs_group_id)
      bs_memberships = Bookshare::CommunityGroupMembership.where(community_group_id: bs_group_id).to_a

      bs_memberships.each do |bs_membership|
        next unless @user_map[bs_membership.user_id] # Skip if user wasn't migrated

        gs_user_id = @user_map[bs_membership.user_id]
        gs_membership = CommunityGroupMembership.find_or_initialize_by(
          user_id: gs_user_id,
          community_group_id: gs_group_id
        )

        gs_membership.assign_attributes(
          admin: bs_membership.admin || false,
          auto_joined: bs_membership.auto_joined || false
        )

        # Handle sub_group_id if present (if Bookshare has sub_groups table)
        # Note: This assumes Bookshare has a sub_groups table. Adjust if needed.
        if bs_membership.respond_to?(:sub_group_id) && bs_membership.sub_group_id.present?
          # If Bookshare has SubGroup model, migrate it
          # Otherwise, sub_group_id will be nil and can be set manually later
          gs_membership.sub_group_id = nil # Set manually if needed after migration
        end

        if gs_membership.new_record?
          gs_membership.created_at = bs_membership.created_at
        end
        gs_membership.updated_at = bs_membership.updated_at

        gs_membership.save!(validate: false)
      end
    end

    def migrate_books_to_items!
      puts ""
      puts "-- Migrating books from Bookshare to GivingShelf items table (type='Book')"

      bookshare_books = Bookshare::Book.all.to_a
      puts "Found #{bookshare_books.length} books in Bookshare DB"

      bookshare_books.each_with_index do |bs_book, idx|
        puts "  [#{idx + 1}/#{bookshare_books.length}] Migrating book: #{bs_book.title}" if (idx % 100).zero?

        next unless @user_map[bs_book.user_id] # Skip if owner wasn't migrated

        if @dry_run
          @book_map[bs_book.id] = bs_book.id
          next
        end

        gs_user_id = @user_map[bs_book.user_id]
        gs_item = Item.find_or_initialize_by(id: bs_book.id, type: "Book")
        gs_item.assign_attributes(
          user_id: gs_user_id,
          title: bs_book.title,
          author: bs_book.author,
          condition: bs_book.condition,
          summary: bs_book.summary,
          details: bs_book.details,
          meta: bs_book.meta,
          cover_image: bs_book.cover_image,
          isbn: bs_book.isbn,
          genre: bs_book.genre,
          published_year: bs_book.published_year,
          status: bs_book.status || 0,
          view_count: bs_book.view_count || 0,
          personal_note: bs_book.personal_note,
          pickup_method: bs_book.pickup_method,
          pickup_address: bs_book.pickup_address
        )

        if gs_item.new_record?
          gs_item.created_at = bs_book.created_at
        end
        gs_item.updated_at = bs_book.updated_at

        gs_item.save!(validate: false)
        @book_map[bs_book.id] = gs_item.id

        # TODO: Migrate Active Storage attachments if needed
        # This would require copying blobs and attachments from Bookshare DB
      end

      puts "-- Book migration complete"
    end

    def migrate_group_book_availabilities!
      puts ""
      puts "-- Migrating group_book_availabilities to group_item_availabilities"

      bs_availabilities = Bookshare::GroupBookAvailability.all.to_a
      puts "Found #{bs_availabilities.length} availabilities in Bookshare DB"

      created_count = 0
      skipped_count = 0

      bs_availabilities.each_with_index do |bs_avail, idx|
        puts "  [#{idx + 1}/#{bs_availabilities.length}] Migrating availability" if (idx % 200).zero?

        next unless @book_map[bs_avail.book_id] && @group_map[bs_avail.community_group_id]

        if @dry_run
          next
        end

        gs_item_id = @book_map[bs_avail.book_id]
        gs_group_id = @group_map[bs_avail.community_group_id]

        gs_avail = GroupItemAvailability.find_or_initialize_by(
          item_id: gs_item_id,
          community_group_id: gs_group_id
        )

        if gs_avail.new_record?
          gs_avail.created_at = bs_avail.created_at
          gs_avail.updated_at = bs_avail.updated_at
          gs_avail.save!(validate: false)
          created_count += 1
        else
          skipped_count += 1
        end
      end

      puts "Created: #{created_count}, Skipped (duplicates): #{skipped_count}"
      puts "-- Availability migration complete"
    end

    def migrate_book_requests!
      puts ""
      puts "-- Migrating book_requests to item_requests"

      bs_requests = Bookshare::BookRequest.all.to_a
      puts "Found #{bs_requests.length} requests in Bookshare DB"

      bs_requests.each_with_index do |bs_request, idx|
        puts "  [#{idx + 1}/#{bs_requests.length}] Migrating request" if (idx % 100).zero?

        next unless @book_map[bs_request.book_id]
        next unless @user_map[bs_request.requester_id]
        next unless @user_map[bs_request.owner_id]

        if @dry_run
          @request_map[bs_request.id] = bs_request.id
          next
        end

        gs_item_id = @book_map[bs_request.book_id]
        gs_requester_id = @user_map[bs_request.requester_id]
        gs_owner_id = @user_map[bs_request.owner_id]

        gs_request = ItemRequest.find_or_initialize_by(id: bs_request.id)
        gs_request.assign_attributes(
          item_id: gs_item_id,
          requester_id: gs_requester_id,
          owner_id: gs_owner_id,
          status: bs_request.status || 0,
          message: bs_request.message
        )

        if gs_request.new_record?
          gs_request.created_at = bs_request.created_at
        end
        gs_request.updated_at = bs_request.updated_at

        gs_request.save!(validate: false)
        @request_map[bs_request.id] = gs_request.id
      end

      puts "-- Request migration complete"
    end

    def migrate_messages!
      puts ""
      puts "-- Migrating messages to reference item_requests"

      bs_messages = Bookshare::Message.all.to_a
      puts "Found #{bs_messages.length} messages in Bookshare DB"

      created_count = 0
      skipped_count = 0

      bs_messages.each_with_index do |bs_message, idx|
        puts "  [#{idx + 1}/#{bs_messages.length}] Migrating message" if (idx % 200).zero?

        next unless @request_map[bs_message.book_request_id]
        next unless @user_map[bs_message.user_id]

        if @dry_run
          next
        end

        gs_request_id = @request_map[bs_message.book_request_id]
        gs_user_id = @user_map[bs_message.user_id]

        gs_message = Message.find_or_initialize_by(id: bs_message.id)
        gs_message.assign_attributes(
          item_request_id: gs_request_id,
          user_id: gs_user_id,
          content: bs_message.content,
          read_at: bs_message.read_at
        )

        if gs_message.new_record?
          gs_message.created_at = bs_message.created_at
        end
        gs_message.updated_at = bs_message.updated_at

        gs_message.save!(validate: false)
        created_count += 1
      end

      puts "Created: #{created_count}, Skipped: #{skipped_count}"
      puts "-- Message migration complete"
    end
  end
end
