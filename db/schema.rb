# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[8.1].define(version: 2026_11_20_200000) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"

  create_table "active_storage_attachments", force: :cascade do |t|
    t.string "name", null: false
    t.string "record_type", null: false
    t.bigint "record_id", null: false
    t.bigint "blob_id", null: false
    t.datetime "created_at", null: false
    t.index ["blob_id"], name: "index_active_storage_attachments_on_blob_id"
    t.index ["record_type", "record_id", "name", "blob_id"], name: "index_active_storage_attachments_uniqueness", unique: true
  end

  create_table "active_storage_blobs", force: :cascade do |t|
    t.string "key", null: false
    t.string "filename", null: false
    t.string "content_type"
    t.text "metadata"
    t.string "service_name", null: false
    t.bigint "byte_size", null: false
    t.string "checksum"
    t.datetime "created_at", null: false
    t.index ["key"], name: "index_active_storage_blobs_on_key", unique: true
  end

  create_table "active_storage_variant_records", force: :cascade do |t|
    t.bigint "blob_id", null: false
    t.string "variation_digest", null: false
    t.index ["blob_id", "variation_digest"], name: "index_active_storage_variant_records_uniqueness", unique: true
  end

  create_table "community_group_memberships", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.bigint "community_group_id", null: false
    t.boolean "admin", default: false, null: false
    t.boolean "auto_joined", default: false, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.bigint "group_membership_request_id"
    t.bigint "sub_group_id"
    t.index ["admin"], name: "index_community_group_memberships_on_admin"
    t.index ["community_group_id"], name: "index_community_group_memberships_on_community_group_id"
    t.index ["group_membership_request_id"], name: "idx_on_group_membership_request_id_705f4891ef"
    t.index ["sub_group_id"], name: "index_community_group_memberships_on_sub_group_id"
    t.index ["user_id", "community_group_id"], name: "index_cgm_on_user_and_group", unique: true
    t.index ["user_id"], name: "index_community_group_memberships_on_user_id"
  end

  create_table "community_groups", force: :cascade do |t|
    t.string "name", null: false
    t.string "group_description", limit: 100
    t.string "domain"
    t.string "short_name", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.boolean "public", default: false, null: false
    t.string "support_item_types", limit: 10
    t.index ["domain"], name: "index_community_groups_on_domain", unique: true
    t.index ["public"], name: "index_community_groups_on_public"
    t.index ["short_name"], name: "index_community_groups_on_short_name", unique: true
    t.index ["support_item_types"], name: "index_community_groups_on_support_item_types"
  end

  create_table "group_item_availabilities", force: :cascade do |t|
    t.bigint "item_id", null: false
    t.bigint "community_group_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.bigint "sub_group_id"
    t.index ["community_group_id", "sub_group_id"], name: "index_gia_on_group_and_sub_group"
    t.index ["community_group_id"], name: "index_group_item_availabilities_on_community_group_id"
    t.index ["item_id", "community_group_id"], name: "index_gia_on_item_id_and_community_group_id", unique: true
    t.index ["item_id"], name: "index_group_item_availabilities_on_item_id"
    t.index ["sub_group_id"], name: "index_group_item_availabilities_on_sub_group_id"
  end

  create_table "group_membership_requests", force: :cascade do |t|
    t.bigint "community_group_id", null: false
    t.bigint "requester_id", null: false
    t.string "requester_type", null: false
    t.string "email_address"
    t.text "message"
    t.integer "status", default: 0, null: false
    t.datetime "responded_at"
    t.datetime "accepted_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["community_group_id", "email_address"], name: "index_gmr_unique_invited_by_email_and_group", unique: true, where: "((status = 1) AND (email_address IS NOT NULL))"
    t.index ["community_group_id", "requester_id"], name: "index_gmr_unique_requested_by_user_and_group", unique: true, where: "((status = 0) AND ((requester_type)::text = 'User'::text))"
    t.index ["community_group_id", "status"], name: "idx_on_community_group_id_status_5d9c038d87"
    t.index ["community_group_id"], name: "index_group_membership_requests_on_community_group_id"
    t.index ["email_address"], name: "index_group_membership_requests_on_email_address"
    t.index ["requester_id"], name: "index_group_membership_requests_on_requester_id"
    t.index ["requester_type"], name: "index_group_membership_requests_on_requester_type"
    t.index ["status"], name: "index_group_membership_requests_on_status"
  end

  create_table "growth_stats", force: :cascade do |t|
    t.string "stat_type", null: false
    t.string "stat_name", null: false
    t.string "stat_value", null: false
    t.bigint "community_group_id"
    t.datetime "computed_at", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["community_group_id"], name: "index_growth_stats_on_community_group_id"
    t.index ["stat_type", "stat_name", "community_group_id"], name: "index_growth_stats_per_group_unique", unique: true, where: "(community_group_id IS NOT NULL)"
    t.index ["stat_type", "stat_name"], name: "index_growth_stats_global_unique", unique: true, where: "(community_group_id IS NULL)"
  end

  create_table "item_requests", force: :cascade do |t|
    t.bigint "item_id", null: false
    t.bigint "requester_id", null: false
    t.bigint "owner_id"
    t.integer "status", default: 0, null: false
    t.text "message"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["item_id", "requester_id"], name: "index_item_requests_on_item_id_and_requester_id", unique: true
    t.index ["item_id"], name: "index_item_requests_on_item_id"
    t.index ["owner_id"], name: "index_item_requests_on_owner_id"
    t.index ["requester_id"], name: "index_item_requests_on_requester_id"
    t.index ["status"], name: "index_item_requests_on_status"
  end

  create_table "items", force: :cascade do |t|
    t.string "type", null: false
    t.bigint "user_id"
    t.string "title"
    t.string "author"
    t.string "isbn"
    t.string "genre"
    t.integer "published_year"
    t.string "brand"
    t.string "age_range"
    t.string "condition"
    t.text "summary"
    t.integer "status", default: 0, null: false
    t.integer "view_count", default: 0, null: false
    t.text "personal_note"
    t.string "pickup_method"
    t.text "pickup_address"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.integer "min_age"
    t.integer "max_age"
    t.boolean "wishlist_item", default: false, null: false
    t.datetime "deleted_at"
    t.index ["deleted_at"], name: "index_items_on_deleted_at"
    t.index ["isbn"], name: "index_items_on_isbn", where: "(isbn IS NOT NULL)"
    t.index ["min_age", "max_age"], name: "index_items_on_min_age_and_max_age"
    t.index ["status"], name: "index_items_on_status"
    t.index ["type"], name: "index_items_on_type"
    t.index ["user_id"], name: "index_items_on_user_id"
  end

  create_table "messages", force: :cascade do |t|
    t.bigint "item_request_id", null: false
    t.bigint "user_id", null: false
    t.text "content"
    t.datetime "read_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.integer "request_transition_status"
    t.index ["item_request_id", "created_at"], name: "index_messages_on_item_request_id_and_created_at"
    t.index ["item_request_id"], name: "index_messages_on_item_request_id"
    t.index ["user_id"], name: "index_messages_on_user_id"
  end

  create_table "sessions", force: :cascade do |t|
    t.string "session_id", null: false
    t.text "data"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["session_id"], name: "index_sessions_on_session_id", unique: true
    t.index ["updated_at"], name: "index_sessions_on_updated_at"
  end

  create_table "sub_groups", force: :cascade do |t|
    t.string "name", null: false
    t.bigint "community_group_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["community_group_id"], name: "index_sub_groups_on_community_group_id"
  end

  create_table "user_notifications", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.string "notifiable_type", null: false
    t.bigint "notifiable_id", null: false
    t.string "kind", null: false
    t.datetime "sent_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["notifiable_type", "notifiable_id"], name: "index_user_notifications_on_notifiable"
    t.index ["user_id", "notifiable_type", "notifiable_id", "kind"], name: "index_user_notifications_dedup", unique: true
    t.index ["user_id"], name: "index_user_notifications_on_user_id"
  end

  create_table "user_sessions", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.string "ip_address"
    t.string "user_agent"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "device_fingerprint"
    t.boolean "suspicious_activity", default: false, null: false
    t.index ["device_fingerprint"], name: "index_user_sessions_on_device_fingerprint"
    t.index ["suspicious_activity"], name: "index_user_sessions_on_suspicious_activity"
    t.index ["user_id"], name: "index_user_sessions_on_user_id"
  end

  create_table "users", force: :cascade do |t|
    t.string "email_address", null: false
    t.string "password_digest", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "first_name"
    t.string "last_name"
    t.string "zip_code"
    t.string "phone"
    t.boolean "verified"
    t.decimal "latitude", precision: 10, scale: 7
    t.decimal "longitude", precision: 10, scale: 7
    t.string "otp_secret"
    t.datetime "otp_sent_at"
    t.integer "otp_attempts", default: 0
    t.string "street_address"
    t.string "city"
    t.string "state"
    t.boolean "address_verified", default: false, null: false
    t.integer "trust_score", default: 0, null: false
    t.boolean "admin", default: false, null: false
    t.boolean "group_admin", default: false, null: false
    t.index ["admin"], name: "index_users_on_admin"
    t.index ["email_address"], name: "index_users_on_email_address", unique: true
    t.index ["group_admin"], name: "index_users_on_group_admin"
  end

  add_foreign_key "active_storage_attachments", "active_storage_blobs", column: "blob_id"
  add_foreign_key "active_storage_variant_records", "active_storage_blobs", column: "blob_id"
  add_foreign_key "community_group_memberships", "community_groups"
  add_foreign_key "community_group_memberships", "group_membership_requests"
  add_foreign_key "community_group_memberships", "sub_groups"
  add_foreign_key "community_group_memberships", "users"
  add_foreign_key "group_item_availabilities", "community_groups"
  add_foreign_key "group_item_availabilities", "items"
  add_foreign_key "group_item_availabilities", "sub_groups"
  add_foreign_key "group_membership_requests", "community_groups"
  add_foreign_key "group_membership_requests", "users", column: "requester_id"
  add_foreign_key "growth_stats", "community_groups"
  add_foreign_key "item_requests", "items"
  add_foreign_key "item_requests", "users", column: "owner_id"
  add_foreign_key "item_requests", "users", column: "requester_id"
  add_foreign_key "items", "users"
  add_foreign_key "messages", "item_requests"
  add_foreign_key "messages", "users"
  add_foreign_key "sub_groups", "community_groups"
  add_foreign_key "user_notifications", "users"
  add_foreign_key "user_sessions", "users"
end
