# frozen_string_literal: true

# One-time backfill script.
#
# Run from Rails console (recommended):
#
#   load Rails.root.join("lib/onetime_scripts/backfill_zipcode_group_book_availabilities.rb")
#   OnetimeScripts::BackfillZipcodeGroupBookAvailabilities.run!
#
# Optional:
#   OnetimeScripts::BackfillZipcodeGroupBookAvailabilities.run!(dry_run: true)
#
module OnetimeScripts
  class BackfillZipcodeGroupBookAvailabilities
    def self.run!(dry_run: false)
      new(dry_run: dry_run).run!
    end

    def initialize(dry_run:)
      @dry_run = dry_run
    end

    def run!
      started_at = Time.current
      puts ""
      puts "== BackfillZipcodeGroupBookAvailabilities starting =="
      puts "Time: #{started_at}"
      puts "dry_run=#{@dry_run}"

      zip_group = ensure_zip_group!
      puts "ZIP group id=#{zip_group.id} short_name=#{zip_group.short_name.inspect} name=#{zip_group.name.inspect}"

      ensure_zip_sub_groups_from_existing_books!(zip_group)
      ensure_all_users_membership_and_sub_group!(zip_group)
      ensure_all_books_available_in_zip_group!(zip_group)

      puts "== Done in #{(Time.current - started_at).round(2)}s =="
      true
    rescue => e
      puts "!! FAILED: #{e.class}: #{e.message}"
      puts e.backtrace.first(20).join("\n")
      raise
    end

    private

    def ensure_zip_group!
      zip_group = CommunityGroup.find_by(short_name: CommunityGroup::ZIPCODE_SHORT_NAME)
      return zip_group if zip_group

      puts "-- Creating ZIP group #{CommunityGroup::ZIPCODE_SHORT_NAME.inspect}"
      return CommunityGroup.new if @dry_run

      CommunityGroup.find_or_create_zipcode_group!
    end

    def ensure_zip_sub_groups_from_existing_books!(zip_group)
      puts ""
      puts "-- Ensuring ZIP subgroups from existing books (users with books)"

      zip_codes = User.joins(:books)
        .where.not(zip_code: [ nil, "" ])
        .distinct
        .pluck(:zip_code)
        .map { |z| z.to_s.strip }
        .reject(&:blank?)
        .uniq

      puts "Found #{zip_codes.length} unique zip codes from existing books"

      zip_codes.each_with_index do |zip, idx|
        puts "  [#{idx + 1}/#{zip_codes.length}] ensure SubGroup #{zip.inspect}" if (idx % 200).zero?
        next if @dry_run
        SubGroup.find_or_create_by!(community_group_id: zip_group.id, name: zip)
      end

      puts "-- ZIP subgroup ensure complete"
    end

    def ensure_all_users_membership_and_sub_group!(zip_group)
      puts ""
      puts "-- Ensuring all users are members of ZIP group, and setting membership.sub_group_id to ZIP subgroup"

      users = User.select(:id, :zip_code).to_a
      puts "Total users: #{users.length}"

      created_memberships = 0
      updated_memberships = 0
      created_subgroups = 0

      memberships_by_user_id = CommunityGroupMembership
        .where(community_group_id: zip_group.id, user_id: users.map(&:id))
        .index_by(&:user_id)

      users.each_with_index do |u, idx|
        zip = u.zip_code.to_s.strip
        membership = memberships_by_user_id[u.id]

        if membership.nil?
          created_memberships += 1
          puts "  [user #{idx + 1}/#{users.length}] create membership user_id=#{u.id} zip=#{zip.inspect}"
          unless @dry_run
            begin
              membership = CommunityGroupMembership.create!(
                user_id: u.id,
                community_group_id: zip_group.id,
                admin: false,
                auto_joined: true
              )
              memberships_by_user_id[u.id] = membership
            rescue => e
              puts "  !! ERROR creating membership for user_id=#{u.id} zip=#{zip.inspect}: #{e.class}: #{e.message}"
            end
          end
        end

        next if zip.blank?

        sub_group = SubGroup.find_by(community_group_id: zip_group.id, name: zip)
        if sub_group.nil?
          created_subgroups += 1
          puts "  [user #{idx + 1}/#{users.length}] create subgroup zip=#{zip.inspect}"
          sub_group = SubGroup.create!(community_group_id: zip_group.id, name: zip) unless @dry_run
        end

        next if @dry_run || membership.nil? || sub_group.nil?
        next if membership.sub_group_id == sub_group.id

        updated_memberships += 1
        puts "  [user #{idx + 1}/#{users.length}] update membership id=#{membership.id} set sub_group_id=#{sub_group.id} (zip=#{zip.inspect})"
        membership.update!(sub_group_id: sub_group.id)
      end

      puts "Memberships created: #{created_memberships}"
      puts "Memberships updated: #{updated_memberships}"
      puts "Subgroups created: #{created_subgroups}"
      puts "-- User membership/subgroup backfill complete"
    end

    def ensure_all_books_available_in_zip_group!(zip_group)
      puts ""
      puts "-- Ensuring all books have availability in ZIP group"

      book_ids = Book.pluck(:id)
      puts "Total books: #{book_ids.length}"

      now = Time.current
      rows = book_ids.map do |book_id|
        { book_id: book_id, community_group_id: zip_group.id, created_at: now, updated_at: now }
      end

      if @dry_run
        puts "dry_run: would attempt to insert #{rows.length} availability rows"
      else
        result = GroupBookAvailability.insert_all(
          rows,
          unique_by: "index_gba_on_book_id_and_community_group_id"
        )
        puts "Inserted #{result.rows.length} new availability rows (duplicates ignored)"
      end

      puts "-- Book availability backfill complete"
    end
  end
end
