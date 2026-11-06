class WidenOrderLinePricePrecisionTo5 < ActiveRecord::Migration[8.1]
  # 订单行价格快照成分 5 位小数（与 prices 表对齐）：
  # 报价成分 5 位快照进 2 位列会被截断 → 金额误差；5 位后快照原值保留
  def change
    change_column :order_lines, :base_price, :decimal, precision: 12, scale: 5
    change_column :order_lines, :v1_price, :decimal, precision: 12, scale: 5
    change_column :order_lines, :v2_price, :decimal, precision: 12, scale: 5
  end
end
