# encoding: UTF-8
# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# Note that this schema.rb definition is the authoritative source for your
# database schema. If you need to create the application database on another
# system, you should be using db:schema:load, not running all the migrations
# from scratch. The latter is a flawed and unsustainable approach (the more migrations
# you'll amass, the slower it'll run and the greater likelihood for issues).
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema.define(version: 20200223004617) do

  # These are extensions that must be enabled in order to support this database
  enable_extension "plpgsql"

  create_table "availabilities", force: :cascade do |t|
    t.integer  "user_id"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.integer  "shift",                              null: false
    t.date     "date",                               null: false
    t.boolean  "implicitly_created", default: false, null: false
    t.boolean  "free",                               null: false
  end

  add_index "availabilities", ["user_id", "shift", "date"], name: "index_availabilities_on_user_id_and_shift_and_date", unique: true, using: :btree
  add_index "availabilities", ["user_id"], name: "index_availabilities_on_user_id", using: :btree

  create_table "default_availabilities", force: :cascade do |t|
    t.integer  "user_id"
    t.integer  "cwday"
    t.integer  "shift"
    t.boolean  "free"
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  add_index "default_availabilities", ["user_id", "shift", "cwday"], name: "index_default_availabilities_on_user_id_and_shift_and_cwday", unique: true, using: :btree
  add_index "default_availabilities", ["user_id"], name: "index_default_availabilities_on_user_id", using: :btree

  create_table "messages", force: :cascade do |t|
    t.integer  "shift",      null: false
    t.text     "body"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.date     "date",       null: false
  end

  create_table "on_call_reminders", force: :cascade do |t|
    t.integer  "month",         null: false
    t.integer  "year",          null: false
    t.text     "user_ids",      null: false
    t.datetime "created_at",    null: false
    t.datetime "updated_at",    null: false
    t.string   "mailer_method", null: false
  end

  create_table "on_calls", force: :cascade do |t|
    t.date     "date",               null: false
    t.integer  "shift",              null: false
    t.integer  "user_id",            null: false
    t.datetime "created_at",         null: false
    t.datetime "updated_at",         null: false
    t.boolean  "prior_availability"
    t.integer  "location",           null: false
  end

  add_index "on_calls", ["shift", "date", "location"], name: "index_on_calls_on_shift_and_date_and_location", unique: true, using: :btree
  add_index "on_calls", ["user_id"], name: "index_on_calls_on_user_id", using: :btree

  create_table "requests", force: :cascade do |t|
    t.integer  "user_id"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.string   "text",               limit: 255
    t.integer  "shift",                                              null: false
    t.date     "date",                                               null: false
    t.integer  "state",                          default: 0,         null: false
    t.integer  "fulfilling_swap_id"
    t.integer  "availability_id"
    t.string   "type",                           default: "Request", null: false
    t.integer  "location",                                           null: false
  end

  add_index "requests", ["user_id", "shift", "date", "location"], name: "index_requests_on_user_id_and_shift_and_date_and_location", unique: true, using: :btree

  create_table "signup_reminders", force: :cascade do |t|
    t.integer  "month",         null: false
    t.integer  "year",          null: false
    t.text     "user_ids",      null: false
    t.datetime "created_at",    null: false
    t.datetime "updated_at",    null: false
    t.string   "mailer_method", null: false
    t.integer  "day",           null: false
    t.integer  "event_type",    null: false
  end

  create_table "users", force: :cascade do |t|
    t.string   "name",                         limit: 255
    t.string   "email",                        limit: 255
    t.datetime "created_at"
    t.datetime "updated_at"
    t.string   "password_digest",              limit: 255
    t.string   "remember_token",               limit: 255
    t.boolean  "admin",                                    default: false
    t.integer  "vic"
    t.boolean  "disabled",                                 default: false
    t.integer  "failed_login_attempts",                    default: 0
    t.string   "confirmation_digest",          limit: 255
    t.boolean  "confirmed",                                default: false
    t.boolean  "staff",                                    default: false, null: false
    t.integer  "volunteer_type"
    t.string   "home_phone"
    t.string   "cell_phone"
    t.integer  "regular_shift"
    t.integer  "regular_cwday"
    t.integer  "first_day_of_week_preference",             default: 0,     null: false
    t.integer  "location",                                                 null: false
  end

  add_index "users", ["email"], name: "index_users_on_email", unique: true, using: :btree
  add_index "users", ["name"], name: "index_users_on_name", unique: true, using: :btree
  add_index "users", ["remember_token"], name: "index_users_on_remember_token", using: :btree
  add_index "users", ["vic"], name: "index_users_on_vic", unique: true, using: :btree

  add_foreign_key "on_calls", "users"
end
