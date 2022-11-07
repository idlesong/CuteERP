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

ActiveRecord::Schema.define(version: 20221106072053) do

  # These are extensions that must be enabled in order to support this database
  enable_extension "plpgsql"

  create_table "attachments", force: :cascade do |t|
    t.string   "name"
    t.string   "description"
    t.datetime "created_at",            null: false
    t.datetime "updated_at",            null: false
    t.string   "document_file_name"
    t.string   "document_content_type"
    t.integer  "document_file_size"
    t.datetime "document_updated_at"
  end

  create_table "carts", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "contacts", force: :cascade do |t|
    t.string   "name"
    t.string   "title"
    t.string   "mobile"
    t.string   "telephone"
    t.string   "email"
    t.string   "note"
    t.datetime "created_at",  null: false
    t.datetime "updated_at",  null: false
    t.integer  "customer_id"
    t.string   "address"
  end

  create_table "customers", force: :cascade do |t|
    t.string   "name"
    t.text     "address"
    t.date     "since"
    t.decimal  "balance"
    t.string   "contact"
    t.string   "telephone"
    t.datetime "created_at",                      null: false
    t.datetime "updated_at",                      null: false
    t.string   "full_name"
    t.string   "sales_type"
    t.string   "payment"
    t.text     "invoice_address"
    t.text     "deliver_address"
    t.string   "currency",        default: "RMB"
    t.string   "ship_contact"
    t.text     "ship_address"
    t.string   "ship_telephone"
    t.decimal  "credit"
  end

  create_table "items", force: :cascade do |t|
    t.string   "name"
    t.string   "partNo"
    t.string   "package"
    t.string   "imageURL"
    t.datetime "created_at",  null: false
    t.datetime "updated_at",  null: false
    t.string   "description"
    t.decimal  "volume"
    t.decimal  "weight"
    t.integer  "moq"
    t.integer  "mop"
    t.string   "assembled"
    t.integer  "index"
    t.string   "group"
    t.string   "family"
    t.string   "base_item"
    t.string   "extra_item"
  end

  create_table "line_items", force: :cascade do |t|
    t.integer  "item_id"
    t.datetime "created_at",                                           null: false
    t.datetime "updated_at",                                           null: false
    t.integer  "quantity",                                 default: 1
    t.integer  "quantity_issued",                          default: 0
    t.integer  "line_id"
    t.string   "line_type"
    t.integer  "refer_line_id"
    t.decimal  "fixed_price",      precision: 8, scale: 2
    t.integer  "cart_id"
    t.string   "full_part_number"
    t.string   "full_name"
    t.integer  "price_id"
    t.string   "remark"
  end

  add_index "line_items", ["line_id"], name: "index_line_items_on_line_id", using: :btree

  create_table "opportunities", force: :cascade do |t|
    t.string   "priority"
    t.string   "project_type"
    t.string   "solution"
    t.string   "note"
    t.datetime "created_at",   null: false
    t.datetime "updated_at",   null: false
    t.integer  "customer_id"
  end

  create_table "oppostatuses", force: :cascade do |t|
    t.string   "status"
    t.string   "issue"
    t.datetime "created_at",       null: false
    t.datetime "updated_at",       null: false
    t.integer  "opportunity_id"
    t.string   "todo_status"
    t.string   "todo_description"
    t.integer  "user_id"
    t.string   "status_mark"
  end

  create_table "orders", force: :cascade do |t|
    t.string   "name"
    t.text     "address"
    t.string   "email"
    t.string   "pay_type"
    t.datetime "created_at",                                    null: false
    t.datetime "updated_at",                                    null: false
    t.integer  "customer_id"
    t.string   "order_number"
    t.string   "telephone"
    t.string   "ship_contact"
    t.text     "ship_address"
    t.string   "ship_telephone"
    t.decimal  "exchange_rate",         precision: 8, scale: 2
    t.string   "document_file_name"
    t.string   "document_content_type"
    t.integer  "document_file_size"
    t.datetime "document_updated_at"
    t.string   "remark"
  end

  create_table "posts", force: :cascade do |t|
    t.string   "title"
    t.text     "content"
    t.string   "subject"
    t.datetime "created_at",   null: false
    t.datetime "updated_at",   null: false
    t.string   "internal_url"
  end

  create_table "prices", force: :cascade do |t|
    t.integer  "item_id"
    t.integer  "customer_id"
    t.decimal  "price"
    t.string   "payment_terms"
    t.string   "condition"
    t.string   "sales_suggestion"
    t.string   "department_suggestion"
    t.string   "finance_suggestion"
    t.string   "boss_suggestion"
    t.datetime "created_at",                                    null: false
    t.datetime "updated_at",                                    null: false
    t.string   "status"
    t.integer  "quotation_id"
    t.string   "remark"
    t.decimal  "base_price",            precision: 8, scale: 2
    t.decimal  "extra_price",           precision: 8, scale: 2
  end

  create_table "quotations", force: :cascade do |t|
    t.string   "quotation_number"
    t.string   "remark"
    t.integer  "customer_id"
    t.datetime "created_at",       null: false
    t.datetime "updated_at",       null: false
  end

  create_table "sales_orders", force: :cascade do |t|
    t.string   "serial_number"
    t.integer  "customer_id"
    t.string   "bill_contact"
    t.text     "bill_address"
    t.string   "bill_telephone"
    t.string   "ship_contact"
    t.text     "ship_address"
    t.string   "ship_telephone"
    t.string   "payment_term"
    t.datetime "created_at",                              null: false
    t.datetime "updated_at",                              null: false
    t.datetime "delivery_date"
    t.string   "delivery_status"
    t.decimal  "exchange_rate",   precision: 8, scale: 2
    t.datetime "delivery_plan"
    t.string   "remark"
  end

  create_table "set_prices", force: :cascade do |t|
    t.integer  "item_id"
    t.string   "order_quantity"
    t.decimal  "price"
    t.string   "sell_by"
    t.datetime "released_at"
    t.datetime "created_at",                             null: false
    t.datetime "updated_at",                             null: false
    t.decimal  "base_price",     precision: 8, scale: 2
    t.decimal  "extra_price",    precision: 8, scale: 2
  end

  create_table "settings", force: :cascade do |t|
    t.string   "var",         null: false
    t.text     "value"
    t.integer  "target_id",   null: false
    t.string   "target_type", null: false
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  add_index "settings", ["target_type", "target_id", "var"], name: "index_settings_on_target_type_and_target_id_and_var", unique: true, using: :btree

  create_table "tasks", force: :cascade do |t|
    t.string   "description"
    t.string   "status"
    t.datetime "created_at",    null: false
    t.datetime "updated_at",    null: false
    t.integer  "oppostatus_id"
  end

  create_table "users", force: :cascade do |t|
    t.string   "name"
    t.string   "hashed_password"
    t.string   "salt"
    t.datetime "created_at",      null: false
    t.datetime "updated_at",      null: false
    t.string   "email"
    t.string   "telephone"
    t.string   "group"
  end

end
