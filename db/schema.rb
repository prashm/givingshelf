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

ActiveRecord::Schema[8.0].define(version: 2025_12_12_000638) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"

  create_table "active_record_sessions", id: { type: :string, limit: 128 }, force: :cascade do |t|
    t.text "data"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["updated_at"], name: "index_active_record_sessions_on_updated_at"
  end

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

  create_table "book_requests", force: :cascade do |t|
    t.integer "requester_id", null: false
    t.integer "book_id", null: false
    t.integer "status", default: 0, null: false
    t.text "message"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.bigint "owner_id", null: false
    t.index ["book_id", "requester_id"], name: "index_book_requests_on_book_id_and_requester_id", unique: true
    t.index ["book_id"], name: "index_book_requests_on_book_id"
    t.index ["owner_id"], name: "index_book_requests_on_owner_id"
    t.index ["requester_id"], name: "index_book_requests_on_requester_id"
    t.index ["status"], name: "index_book_requests_on_status"
  end

  create_table "books", force: :cascade do |t|
    t.string "title"
    t.string "author"
    t.text "details"
    t.text "meta"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.integer "user_id", null: false
    t.string "condition"
    t.text "summary"
    t.string "cover_image"
    t.string "isbn"
    t.string "genre"
    t.integer "published_year"
    t.integer "status", default: 0, null: false
    t.integer "view_count", default: 0, null: false
    t.text "personal_note"
    t.string "pickup_method"
    t.text "pickup_address"
    t.index ["status"], name: "index_books_on_status"
    t.index ["user_id"], name: "index_books_on_user_id"
  end

  create_table "messages", force: :cascade do |t|
    t.bigint "book_request_id", null: false
    t.bigint "user_id", null: false
    t.text "content"
    t.datetime "read_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["book_request_id", "created_at"], name: "index_messages_on_book_request_id_and_created_at"
    t.index ["book_request_id"], name: "index_messages_on_book_request_id"
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

  create_table "user_sessions", force: :cascade do |t|
    t.integer "user_id", null: false
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
    t.string "otp_secret"
    t.datetime "otp_sent_at"
    t.integer "otp_attempts", default: 0
    t.string "street_address"
    t.string "city"
    t.string "state"
    t.boolean "address_verified", default: false, null: false
    t.integer "trust_score", default: 0, null: false
    t.boolean "admin", default: false, null: false
    t.index ["admin"], name: "index_users_on_admin"
    t.index ["email_address"], name: "index_users_on_email_address", unique: true
  end

  add_foreign_key "active_storage_attachments", "active_storage_blobs", column: "blob_id"
  add_foreign_key "active_storage_variant_records", "active_storage_blobs", column: "blob_id"
  add_foreign_key "book_requests", "books"
  add_foreign_key "book_requests", "users", column: "owner_id"
  add_foreign_key "book_requests", "users", column: "requester_id"
  add_foreign_key "books", "users"
  add_foreign_key "messages", "book_requests"
  add_foreign_key "messages", "users"
  add_foreign_key "user_sessions", "users"
end
