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

ActiveRecord::Schema[8.1].define(version: 2026_02_23_000001) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"

  create_table "inbound_webhooks_webhooks", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.text "error_backtrace"
    t.text "error_message"
    t.string "event_type", null: false
    t.json "headers"
    t.string "ip_address"
    t.json "payload", null: false
    t.datetime "processed_at"
    t.string "provider", null: false
    t.string "provider_event_id"
    t.integer "retry_count", default: 0
    t.string "status", default: "pending", null: false
    t.datetime "updated_at", null: false
    t.index ["event_type"], name: "index_inbound_webhooks_webhooks_on_event_type"
    t.index ["provider", "event_type"], name: "index_inbound_webhooks_webhooks_on_provider_and_event_type"
    t.index ["provider"], name: "index_inbound_webhooks_webhooks_on_provider"
    t.index ["provider_event_id"], name: "index_inbound_webhooks_webhooks_on_provider_event_id", unique: true, where: "(provider_event_id IS NOT NULL)"
    t.index ["status", "created_at"], name: "index_inbound_webhooks_webhooks_on_status_and_created_at"
    t.index ["status"], name: "index_inbound_webhooks_webhooks_on_status"
  end

  create_table "users", force: :cascade do |t|
    t.boolean "admin", default: false, null: false
    t.datetime "created_at", null: false
    t.string "email", default: "", null: false
    t.string "encrypted_password", default: "", null: false
    t.datetime "remember_created_at"
    t.datetime "reset_password_sent_at"
    t.string "reset_password_token"
    t.datetime "updated_at", null: false
    t.index ["email"], name: "index_users_on_email", unique: true
    t.index ["reset_password_token"], name: "index_users_on_reset_password_token", unique: true
  end
end
