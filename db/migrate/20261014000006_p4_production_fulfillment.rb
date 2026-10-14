# P4 生产履约重构：
# - production_lines 替代 line_items 的销售订单（六联单）侧
# - production_allocations 分配台账（D2）替代 refer_line_id/quantity_issued 签发机制
# - shipments/shipment_lines 出库单（可多次发货，快递号仅存储）
# - sales_orders：delivery_plan → required_date（客户要求交期）；+end_customer_id；
#   delivery_date/delivery_status 废弃（发货时间由末次出库单派生）
# - 存量迁移后 line_items/carts 退场
class P4ProductionFulfillment < ActiveRecord::Migration[8.1]
  def up
    create_table :production_lines do |t|
      t.references :sales_order, null: false
      t.references :item
      t.integer :quantity, default: 1, null: false
      t.string :version
      t.string :full_name
      t.string :remark
      t.timestamps
    end

    create_table :production_allocations do |t|
      t.references :production_line, null: false
      t.references :order_line, null: false
      t.integer :quantity, null: false
      t.timestamps
    end
    add_check_constraint :production_allocations, "quantity > 0", name: "chk_allocation_qty_positive"

    create_table :shipments do |t|
      t.references :sales_order, null: false
      t.datetime :shipped_at, null: false
      t.string :tracking_no
      t.string :note
      t.timestamps
    end

    create_table :shipment_lines do |t|
      t.references :shipment, null: false
      t.references :production_line, null: false
      t.integer :quantity, null: false
      t.timestamps
    end

    # ---- 单头调整 ----
    rename_column :sales_orders, :delivery_plan, :required_date
    add_column :sales_orders, :end_customer_id, :integer
    add_index :sales_orders, :serial_number, unique: true

    migrate_sales_order_line_items
    backfill_shipments

    drop_table :line_items
    drop_table :carts

    # quantity_issued 签发计数由分配台账聚合派生，字段退场
    remove_column :order_lines, :quantity_issued
    remove_column :sales_orders, :delivery_date
    remove_column :sales_orders, :delivery_status
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end

  private

  # 销售订单侧 line_items → production_lines；refer/quantity_issued → 分配台账
  def migrate_sales_order_line_items
    say_with_time "migrate sales order line_items" do
      rows = select_all(<<~SQL).to_a
        SELECT * FROM line_items WHERE line_type = 'SalesOrder' ORDER BY line_id, id
      SQL
      mapping = {}

      rows.each do |r|
        pl_id = select_value(<<~SQL)
          INSERT INTO production_lines (sales_order_id, item_id, quantity, full_name, remark,
                                        created_at, updated_at)
          VALUES (#{r['line_id']}, #{r['item_id'] || 'NULL'}, #{r['quantity'].to_i},
                  #{connection.quote(r['full_name'].to_s)}, #{connection.quote(r['remark'].to_s)},
                  NOW(), NOW())
          RETURNING id
        SQL
        mapping[r["id"]] = pl_id

        # 存量签发关系回填为台账（P3 已把 refer_line_id 重映射到 order_lines）
        next if r["refer_line_id"].blank?
        next unless OrderLineExistsCheck.call(self, r["refer_line_id"])

        execute <<~SQL
          INSERT INTO production_allocations (production_line_id, order_line_id, quantity, created_at, updated_at)
          VALUES (#{pl_id}, #{r['refer_line_id']}, #{r['quantity'].to_i}, NOW(), NOW())
        SQL
      end
      mapping.size
    end
  end

  # 已发货（delivery_date）的六联单生成存量出库单，整单数量一次出完
  def backfill_shipments
    say_with_time "backfill shipments from delivery_date" do
      so_ids = select_all("SELECT id, delivery_date FROM sales_orders WHERE delivery_date IS NOT NULL").map { |r| r["id"] }
      so_ids.each do |so_id|
        sh_id = select_value(<<~SQL)
          INSERT INTO shipments (sales_order_id, shipped_at, note, created_at, updated_at)
          VALUES (#{so_id},
                  (SELECT delivery_date FROM sales_orders WHERE id = #{so_id}),
                  '存量迁移', NOW(), NOW())
          RETURNING id
        SQL
        execute <<~SQL
          INSERT INTO shipment_lines (shipment_id, production_line_id, quantity, created_at, updated_at)
          SELECT #{sh_id}, id, quantity, NOW(), NOW() FROM production_lines WHERE sales_order_id = #{so_id}
        SQL
      end
      so_ids.size
    end
  end
end

# 迁移期辅助：校验 order_line 存在（隔离命名空间避免 autoload 干扰）
module OrderLineExistsCheck
  def self.call(migration, id)
    migration.select_value("SELECT 1 FROM order_lines WHERE id = #{Integer(id)} LIMIT 1").present?
  end
end
