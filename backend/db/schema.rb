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

ActiveRecord::Schema[8.1].define(version: 2026_09_25_100200) do
  create_table "budgets", charset: "utf8mb4", collation: "utf8mb4_0900_ai_ci", force: :cascade do |t|
    t.string "year_month", limit: 7, null: false
    t.integer "amount", null: false
    t.datetime "created_at", default: -> { "CURRENT_TIMESTAMP(6)" }, null: false
    t.datetime "updated_at", default: -> { "CURRENT_TIMESTAMP(6)" }, null: false
    t.index ["year_month"], name: "index_budgets_on_year_month", unique: true
    t.check_constraint "(`amount` >= 0) and (`amount` <= 99999999)", name: "budgets_amount_check"
  end

  create_table "categories", charset: "utf8mb4", collation: "utf8mb4_0900_ai_ci", force: :cascade do |t|
    t.string "name", limit: 50, null: false
    t.string "category_type", limit: 10, null: false
    t.datetime "created_at", default: -> { "CURRENT_TIMESTAMP(6)" }, null: false
    t.index ["name", "category_type"], name: "index_categories_on_name_and_category_type", unique: true
    t.check_constraint "`category_type` in (_utf8mb4'INCOME',_utf8mb4'EXPENSE')", name: "categories_category_type_check"
  end

  create_table "entries", charset: "utf8mb4", collation: "utf8mb4_0900_ai_ci", force: :cascade do |t|
    t.date "entry_date", null: false
    t.bigint "category_id", null: false
    t.integer "amount", null: false
    t.string "memo", limit: 200
    t.datetime "created_at", default: -> { "CURRENT_TIMESTAMP(6)" }, null: false
    t.datetime "updated_at", default: -> { "CURRENT_TIMESTAMP(6)" }, null: false
    t.index ["category_id"], name: "index_entries_on_category_id"
    t.index ["entry_date"], name: "index_entries_on_entry_date"
    t.check_constraint "(`amount` > 0) and (`amount` <= 9999999)", name: "entries_amount_check"
  end

  add_foreign_key "entries", "categories"
end
