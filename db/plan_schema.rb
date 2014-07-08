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
# It's strongly recommended to check this file into your version control system.

ActiveRecord::Schema.define(:version => 20140630054050) do

  create_table "carts", :force => true do |t|
    t.datetime "created_at", :null => false
    t.datetime "updated_at", :null => false
  end

  create_table "contacts", :force => true do |t|
    t.string   "name"
    t.string   "title"
    t.string   "mobile"
    t.string   "telephone"
    t.string   "email"
    t.string   "note"
    t.datetime "created_at",  :null => false
    t.datetime "updated_at",  :null => false
    t.integer  "customer_id"
  end

  create_table "customers", :force => true do |t|
    t.string   "name"
    t.string   "fullname"  #fullname
    t.string   "sales_type" #inner/oversea
    t.string   "payment"   #payment
    t.text     "address"
    t.text     "invoice_address" #invoice address
    t.text     "deliver_address" #deliver address
    t.date     "since"
    t.decimal  "balance"
    t.string   "contact"
    t.string   "telephone"
    t.datetime "created_at", :null => false
    t.datetime "updated_at", :null => false
  end

  create_table "items", :force => true do |t|
    t.string   "name"
    t.string   "partNo"
    t.string   "description"  # need to secify the type
    t.string   "package"
    t.string   "imageURL"
    t.decimal  "price",      :precision => 8, :scale => 2
    t.decimal  "volume"   # quantity of reel
    t.decimal  "net_weight" # 净重
    t.decimal  "weight"     # 毛重
    t.decimal  "moq"        # 最小起定量，
    t.decimal  "mop"        # 最小包装
    t.datetime "created_at",                               :null => false
    t.datetime "updated_at",                               :null => false
  end

  create_table "line_items", :force => true do |t|
    t.integer  "item_id"
    t.integer  "cart_id"
    t.datetime "created_at",                :null => false
    t.datetime "updated_at",                :null => false
    t.integer  "quantity",   :default => 1
    t.integer  "order_id"
  end

  create_table "opportunities", :force => true do |t|
    t.string   "priority"
    t.string   "project_type"
    t.string   "solution"
    t.string   "note"
    t.datetime "created_at",   :null => false
    t.datetime "updated_at",   :null => false
    t.integer  "customer_id"
  end

  create_table "oppostatuses", :force => true do |t|
    t.string   "status"
    t.string   "issue"
    t.datetime "created_at",       :null => false
    t.datetime "updated_at",       :null => false
    t.integer  "opportunity_id"
    t.integer  "user_id"    #assign to todo
    t.string   "todo_status"
    t.string   "todo_description"
  end

  create_table "orders", :force => true do |t|
    t.string   "name"
    t.text     "address"
    t.string   "email"
    t.string   "pay_type"
    t.datetime "created_at",  :null => false
    t.datetime "updated_at",  :null => false
    t.integer  "customer_id"
  end

  create_table "tasks", :force => true do |t|
    t.string   "description"
    t.string   "status"
    t.datetime "created_at",    :null => false
    t.datetime "updated_at",    :null => false
    t.integer  "oppostatus_id"
  end

  create_table "users", :force => true do |t|
    t.string   "name" #替代通信录，group,
    t.string   "email"
    t.string   "telephone"
    t.string   "group" #group/ roles
    t.string   "hashed_password"
    t.string   "salt"
    t.datetime "created_at",      :null => false
    t.datetime "updated_at",      :null => false
  end

end