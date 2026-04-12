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

ActiveRecord::Schema[8.1].define(version: 2026_04_12_171813) do
  create_table "download_logs", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.integer "download_id", null: false
    t.integer "level"
    t.text "message"
    t.datetime "updated_at", null: false
    t.index ["download_id"], name: "index_download_logs_on_download_id"
  end

  create_table "downloads", force: :cascade do |t|
    t.datetime "completed_at"
    t.datetime "created_at", null: false
    t.text "error_message"
    t.string "manga_id"
    t.integer "progress", default: 0
    t.string "source"
    t.datetime "started_at"
    t.integer "status", default: 0
    t.string "title"
    t.datetime "updated_at", null: false
    t.string "url"
    t.string "volumes"
  end

  create_table "settings", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "key"
    t.datetime "updated_at", null: false
    t.text "value"
  end

  add_foreign_key "download_logs", "downloads"
end
