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

ActiveRecord::Schema[8.1].define(version: 2026_06_20_140234) do
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

  create_table "db_backups", force: :cascade do |t|
    t.string "key"
    t.datetime "occurred_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "earned_achievements", force: :cascade do |t|
    t.integer "user_id", null: false
    t.string "achievement_key", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["user_id", "achievement_key"], name: "index_earned_achievements_on_user_id_and_achievement_key", unique: true
    t.index ["user_id"], name: "index_earned_achievements_on_user_id"
  end

  create_table "game_challenges", force: :cascade do |t|
    t.integer "session_id", null: false
    t.string "kind", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["session_id", "kind"], name: "index_game_challenges_on_session_id_and_kind", unique: true
    t.index ["session_id"], name: "index_game_challenges_on_session_id"
  end

  create_table "recovery_codes", force: :cascade do |t|
    t.integer "user_id", null: false
    t.string "code_digest", null: false
    t.datetime "used_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["user_id", "used_at"], name: "index_recovery_codes_on_user_id_and_used_at"
    t.index ["user_id"], name: "index_recovery_codes_on_user_id"
  end

  create_table "sessions", force: :cascade do |t|
    t.integer "user_id", null: false
    t.string "ip_address"
    t.string "user_agent"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["user_id"], name: "index_sessions_on_user_id"
  end

  create_table "users", force: :cascade do |t|
    t.string "email_address", null: false
    t.string "password_digest"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "username", default: "", null: false
    t.datetime "confirmed_at"
    t.string "totp_secret"
    t.boolean "totp_enabled", default: false, null: false
    t.integer "last_totp_at"
    t.string "webauthn_id"
    t.integer "highest_level_completed"
    t.integer "now_playing_level"
    t.boolean "super_admin", default: false, null: false
    t.index "lower(username)", name: "index_users_on_lower_username", unique: true
    t.index ["email_address"], name: "index_users_on_email_address", unique: true
    t.index ["webauthn_id"], name: "index_users_on_webauthn_id", unique: true
  end

  create_table "webauthn_credentials", force: :cascade do |t|
    t.integer "user_id", null: false
    t.string "external_id", null: false
    t.string "public_key", null: false
    t.bigint "sign_count", default: 0, null: false
    t.string "nickname", null: false
    t.datetime "last_used_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["external_id"], name: "index_webauthn_credentials_on_external_id", unique: true
    t.index ["user_id"], name: "index_webauthn_credentials_on_user_id"
  end

  add_foreign_key "active_storage_attachments", "active_storage_blobs", column: "blob_id"
  add_foreign_key "active_storage_variant_records", "active_storage_blobs", column: "blob_id"
  add_foreign_key "earned_achievements", "users"
  add_foreign_key "game_challenges", "sessions"
  add_foreign_key "recovery_codes", "users"
  add_foreign_key "sessions", "users"
  add_foreign_key "webauthn_credentials", "users"
end
