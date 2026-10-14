# P5 年度销售计划（对齐 Plan.xlsx 版式）
# fy 按止年标记：FY2027 = 2026-04 ~ 2027-03
# 度量：quantity / chip_amount（硬件，base_price 口径）/ software_amount（软件，v1+v2 口径）
class P5SalesPlan < ActiveRecord::Migration[8.1]
  def up
    create_table :sales_plan_entries do |t|
      t.integer :fy, null: false
      t.references :customer, null: false
      t.string :product_group, null: false
      t.date :month, null: false
      t.integer :quantity, default: 0
      t.decimal :chip_amount, precision: 12, scale: 2, default: 0
      t.decimal :software_amount, precision: 12, scale: 2, default: 0
      t.timestamps
    end
    add_index :sales_plan_entries, [:fy, :customer_id, :product_group, :month],
              unique: true, name: "idx_sales_plan_on_fy_customer_group_month"
  end

  def down
    drop_table :sales_plan_entries
  end
end
