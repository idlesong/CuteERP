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

ActiveRecord::Schema[8.1].define(version: 2026_10_14_000007) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"

  create_table "active_storage_attachments", force: :cascade do |t|
    t.bigint "blob_id", null: false
    t.datetime "created_at", null: false
    t.string "name", null: false
    t.bigint "record_id", null: false
    t.string "record_type", null: false
    t.index ["blob_id"], name: "index_active_storage_attachments_on_blob_id"
    t.index ["record_type", "record_id", "name", "blob_id"], name: "index_active_storage_attachments_uniqueness", unique: true
  end

  create_table "active_storage_blobs", force: :cascade do |t|
    t.bigint "byte_size", null: false
    t.string "checksum"
    t.string "content_type"
    t.datetime "created_at", null: false
    t.string "filename", null: false
    t.string "key", null: false
    t.text "metadata"
    t.string "service_name", null: false
    t.index ["key"], name: "index_active_storage_blobs_on_key", unique: true
  end

  create_table "active_storage_variant_records", force: :cascade do |t|
    t.bigint "blob_id", null: false
    t.string "variation_digest", null: false
    t.index ["blob_id", "variation_digest"], name: "index_active_storage_variant_records_uniqueness", unique: true
  end

  create_table "attachments", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "description"
    t.string "name"
    t.bigint "post_id"
    t.datetime "updated_at", null: false
    t.index ["post_id"], name: "index_attachments_on_post_id"
  end

  create_table "contacts", force: :cascade do |t|
    t.string "address"
    t.datetime "created_at", null: false
    t.integer "customer_id"
    t.string "email"
    t.string "mobile"
    t.string "name"
    t.string "note"
    t.string "telephone"
    t.string "title"
    t.datetime "updated_at", null: false
  end

  create_table "customers", force: :cascade do |t|
    t.text "address"
    t.decimal "balance"
    t.string "contact"
    t.datetime "created_at", null: false
    t.decimal "credit"
    t.string "currency", default: "RMB"
    t.integer "disty_id"
    t.string "full_name"
    t.text "invoice_address"
    t.string "invoice_contact"
    t.string "invoice_phone"
    t.string "name"
    t.string "name_zh"
    t.string "payment"
    t.string "sales_type"
    t.text "ship_address"
    t.string "ship_contact"
    t.string "ship_telephone"
    t.date "since"
    t.string "telephone"
    t.string "territory"
    t.datetime "updated_at", null: false
    t.index ["disty_id"], name: "index_customers_on_disty_id"
  end

  create_table "exchange_rates", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "currency", default: "USD", null: false
    t.date "month", null: false
    t.decimal "rate", precision: 10, scale: 4, null: false
    t.datetime "updated_at", null: false
    t.index ["month", "currency"], name: "index_exchange_rates_on_month_and_currency", unique: true
  end

  create_table "items", force: :cascade do |t|
    t.string "assembled"
    t.string "base_item"
    t.datetime "created_at", null: false
    t.string "description"
    t.date "eol_at"
    t.string "extra_item"
    t.string "extra_item2"
    t.string "family"
    t.string "generic_part_no", null: false
    t.string "group"
    t.string "imageURL"
    t.integer "index"
    t.integer "mop"
    t.integer "moq"
    t.string "name"
    t.string "name_zh"
    t.string "package"
    t.string "suffix"
    t.datetime "updated_at", null: false
    t.decimal "volume"
    t.decimal "weight"
    t.index ["generic_part_no", "suffix"], name: "index_items_on_generic_part_no_and_suffix", unique: true, nulls_not_distinct: true
    t.index ["generic_part_no"], name: "index_items_on_generic_part_no"
  end

  create_table "opportunities", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.integer "customer_id"
    t.string "note"
    t.string "priority"
    t.string "project_type"
    t.string "solution"
    t.datetime "updated_at", null: false
  end

  create_table "oppostatuses", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "issue"
    t.integer "opportunity_id"
    t.string "status"
    t.string "status_mark"
    t.string "todo_description"
    t.string "todo_status"
    t.datetime "updated_at", null: false
    t.integer "user_id"
  end

  create_table "order_lines", force: :cascade do |t|
    t.decimal "base_price", precision: 8, scale: 2
    t.datetime "created_at", null: false
    t.string "generic_part_no", null: false
    t.integer "line_no", null: false
    t.bigint "order_id", null: false
    t.bigint "price_id"
    t.integer "quantity", default: 1
    t.bigint "refer_order_line_id"
    t.string "remark"
    t.date "required_delivery_date"
    t.datetime "updated_at", null: false
    t.decimal "v1_price", precision: 8, scale: 2
    t.decimal "v2_price", precision: 8, scale: 2
    t.string "version"
    t.index ["generic_part_no"], name: "index_order_lines_on_generic_part_no"
    t.index ["order_id", "line_no"], name: "index_order_lines_on_order_id_and_line_no", unique: true
    t.index ["order_id"], name: "index_order_lines_on_order_id"
    t.index ["price_id"], name: "index_order_lines_on_price_id"
    t.index ["refer_order_line_id"], name: "index_order_lines_on_refer_order_line_id"
  end

  create_table "orders", force: :cascade do |t|
    t.text "address"
    t.datetime "created_at", null: false
    t.string "currency"
    t.integer "customer_id"
    t.string "email"
    t.integer "end_customer_id"
    t.decimal "exchange_rate", precision: 8, scale: 2
    t.string "kind", default: "normal"
    t.string "name"
    t.string "pay_type"
    t.string "po_number", null: false
    t.string "remark"
    t.text "ship_address"
    t.string "ship_contact"
    t.string "ship_telephone"
    t.string "status", default: "draft"
    t.string "telephone"
    t.datetime "updated_at", null: false
    t.index ["po_number"], name: "index_orders_on_po_number", unique: true
  end

  create_table "posts", force: :cascade do |t|
    t.text "content"
    t.datetime "created_at", null: false
    t.string "internal_url"
    t.string "subject"
    t.string "title"
    t.datetime "updated_at", null: false
  end

  create_table "price_list_entries", force: :cascade do |t|
    t.datetime "amended_at"
    t.datetime "created_at", null: false
    t.string "generic_part_no", null: false
    t.integer "min_qty", null: false
    t.decimal "price", precision: 8, scale: 2, null: false
    t.bigint "price_list_release_id", null: false
    t.string "sell_by", default: "OEM", null: false
    t.datetime "updated_at", null: false
    t.index ["price_list_release_id", "generic_part_no", "sell_by", "min_qty"], name: "idx_pl_entries_lookup", unique: true
    t.index ["price_list_release_id"], name: "index_price_list_entries_on_price_list_release_id"
  end

  create_table "price_list_releases", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "note"
    t.date "released_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "prices", force: :cascade do |t|
    t.decimal "base_price", precision: 8, scale: 2
    t.string "boss_suggestion"
    t.string "condition"
    t.datetime "created_at", null: false
    t.string "currency", default: "RMB"
    t.integer "customer_id"
    t.string "customer_name"
    t.string "department_suggestion"
    t.date "effective_from"
    t.date "expired_at"
    t.string "finance_suggestion"
    t.integer "is_prr"
    t.string "part_number"
    t.string "payment_terms"
    t.decimal "price"
    t.string "price_number"
    t.integer "quotation_id"
    t.string "remark"
    t.string "sales_suggestion"
    t.string "status"
    t.datetime "updated_at", null: false
    t.decimal "v1_price", precision: 8, scale: 2
    t.decimal "v2_price", precision: 8, scale: 2
  end

  create_table "production_allocations", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "order_line_id", null: false
    t.bigint "production_line_id", null: false
    t.integer "quantity", null: false
    t.datetime "updated_at", null: false
    t.index ["order_line_id"], name: "index_production_allocations_on_order_line_id"
    t.index ["production_line_id"], name: "index_production_allocations_on_production_line_id"
    t.check_constraint "quantity > 0", name: "chk_allocation_qty_positive"
  end

  create_table "production_lines", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "full_name"
    t.bigint "item_id"
    t.integer "quantity", default: 1, null: false
    t.string "remark"
    t.bigint "sales_order_id", null: false
    t.datetime "updated_at", null: false
    t.string "version"
    t.index ["item_id"], name: "index_production_lines_on_item_id"
    t.index ["sales_order_id"], name: "index_production_lines_on_sales_order_id"
  end

  create_table "quotations", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.integer "customer_id"
    t.string "quotation_number"
    t.string "remark"
    t.datetime "updated_at", null: false
  end

  create_table "sales_orders", force: :cascade do |t|
    t.text "bill_address"
    t.string "bill_contact"
    t.string "bill_telephone"
    t.datetime "created_at", null: false
    t.integer "customer_id"
    t.integer "end_customer_id"
    t.decimal "exchange_rate", precision: 8, scale: 2
    t.string "payment_term"
    t.string "remark"
    t.datetime "required_date"
    t.string "serial_number"
    t.text "ship_address"
    t.string "ship_contact"
    t.string "ship_telephone"
    t.datetime "updated_at", null: false
    t.index ["serial_number"], name: "index_sales_orders_on_serial_number", unique: true
  end

  create_table "sales_plan_entries", force: :cascade do |t|
    t.decimal "chip_amount", precision: 12, scale: 2, default: "0.0"
    t.datetime "created_at", null: false
    t.bigint "customer_id", null: false
    t.integer "fy", null: false
    t.date "month", null: false
    t.string "product_group", null: false
    t.integer "quantity", default: 0
    t.decimal "software_amount", precision: 12, scale: 2, default: "0.0"
    t.datetime "updated_at", null: false
    t.index ["customer_id"], name: "index_sales_plan_entries_on_customer_id"
    t.index ["fy", "customer_id", "product_group", "month"], name: "idx_sales_plan_on_fy_customer_group_month", unique: true
  end

  create_table "settings", force: :cascade do |t|
    t.datetime "created_at"
    t.integer "target_id", null: false
    t.string "target_type", null: false
    t.datetime "updated_at"
    t.text "value"
    t.string "var", null: false
    t.index ["target_type", "target_id", "var"], name: "index_settings_on_target_type_and_target_id_and_var", unique: true
  end

  create_table "shipment_lines", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "production_line_id", null: false
    t.integer "quantity", null: false
    t.bigint "shipment_id", null: false
    t.datetime "updated_at", null: false
    t.index ["production_line_id"], name: "index_shipment_lines_on_production_line_id"
    t.index ["shipment_id"], name: "index_shipment_lines_on_shipment_id"
  end

  create_table "shipments", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "note"
    t.bigint "sales_order_id", null: false
    t.datetime "shipped_at", null: false
    t.string "tracking_no"
    t.datetime "updated_at", null: false
    t.index ["sales_order_id"], name: "index_shipments_on_sales_order_id"
  end

  create_table "tasks", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "description"
    t.integer "oppostatus_id"
    t.string "status"
    t.datetime "updated_at", null: false
  end

  create_table "users", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "email"
    t.string "group"
    t.string "name"
    t.string "password_digest"
    t.string "telephone"
    t.datetime "updated_at", null: false
  end

  add_foreign_key "active_storage_attachments", "active_storage_blobs", column: "blob_id"
  add_foreign_key "active_storage_variant_records", "active_storage_blobs", column: "blob_id"
  add_foreign_key "attachments", "posts"
  add_foreign_key "price_list_entries", "price_list_releases"
end
