# P3 客户订单重构：
# - orders 新增 kind（normal/return, D1）/ status（draft/submitted, D10）/ currency
# - 取消 order_number 内部编号，po_number（客户订单号）成为单据主标识并全局唯一
# - 新建 order_lines 行表（客户订单号+行号 = 行唯一编号），Order 侧 line_items 迁入后删除
# - carts 为签发暂存（P4 由分配台账替代），本迁移不动
class P3CustomerOrders < ActiveRecord::Migration[8.1]
  def up
    add_column :orders, :kind, :string, default: "normal"
    add_column :orders, :status, :string, default: "draft"
    add_column :orders, :currency, :string

    # 存量单均为已确认单
    execute "UPDATE orders SET status = 'submitted'"

    # po_number 回填：空则取 order_number；币别从客户带出（缺省 RMB）；汇率缺省 1
    execute "UPDATE orders SET po_number = TRIM(order_number) WHERE po_number IS NULL OR po_number = ''"
    execute <<~SQL
      UPDATE orders SET currency = COALESCE(
        (SELECT currency FROM customers WHERE customers.id = orders.customer_id), 'RMB')
      WHERE currency IS NULL OR currency = ''
    SQL
    execute "UPDATE orders SET exchange_rate = 1 WHERE exchange_rate IS NULL"

    # po_number 去重（重号者追加 -id 后缀）后全局唯一
    execute <<~SQL
      UPDATE orders o SET po_number = o.po_number || '-' || o.id
      FROM (
        SELECT id, ROW_NUMBER() OVER (PARTITION BY TRIM(po_number) ORDER BY id) rn
        FROM orders WHERE po_number IS NOT NULL
      ) d
      WHERE d.id = o.id AND d.rn > 1
    SQL
    execute "UPDATE orders SET po_number = TRIM(po_number) WHERE po_number LIKE ' %' OR po_number LIKE '% '"
    change_column_null :orders, :po_number, false
    add_index :orders, :po_number, unique: true

    create_table :order_lines do |t|
      t.references :order, null: false
      t.integer :line_no, null: false
      t.string :generic_part_no, null: false
      t.decimal :base_price, precision: 8, scale: 2
      t.decimal :v1_price, precision: 8, scale: 2
      t.decimal :v2_price, precision: 8, scale: 2
      t.references :price
      t.integer :quantity, default: 1
      t.integer :quantity_issued, default: 0
      t.references :refer_order_line
      t.string :version
      t.date :required_delivery_date
      t.string :remark
      t.timestamps
    end
    add_index :order_lines, [:order_id, :line_no], unique: true
    add_index :order_lines, :generic_part_no

    migrate_order_line_items

    remove_column :orders, :order_number
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end

  private

  # Order 侧 line_items → order_lines（历史上无成分拆分，全额记入 base_price）
  def migrate_order_line_items
    rows = select_all(<<~SQL).to_a
      SELECT li.*, i.generic_part_no AS gpno
      FROM line_items li LEFT JOIN items i ON i.id = li.item_id
      WHERE li.line_type = 'Order'
      ORDER BY li.line_id, li.id
    SQL
    mapping = {}

    rows.group_by { |r| r["line_id"] }.each do |_order_id, order_rows|
      order_rows.each_with_index do |r, idx|
        generic = connection.quote(r["gpno"].presence || r["full_part_number"])
        new_id = select_value(<<~SQL)
          INSERT INTO order_lines (order_id, line_no, generic_part_no, base_price, price_id,
                                   quantity, quantity_issued, remark, created_at, updated_at)
          VALUES (#{r['line_id']}, #{idx + 1}, #{generic}, #{r['fixed_price'].to_f},
                  #{r['price_id'] || 'NULL'}, #{r['quantity'].to_i}, #{r['quantity_issued'].to_i},
                  #{connection.quote(r['remark'].to_s)}, NOW(), NOW())
          RETURNING id
        SQL
        mapping[r["id"]] = new_id
      end
    end

    # 冲销行（负数量）的 refer_line_id 指向旧 line_items，改指新行
    rows.each do |r|
      next if r["refer_line_id"].blank? || mapping[r["refer_line_id"]].nil?

      execute "UPDATE order_lines SET refer_order_line_id = #{mapping[r['refer_line_id']]} WHERE id = #{mapping[r['id']]}"
    end

    execute "DELETE FROM line_items WHERE line_type = 'Order'"
  end
end
