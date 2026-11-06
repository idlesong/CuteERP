class WidenPricePrecisionTo5 < ActiveRecord::Migration[8.1]
  # 价格保留 5 位小数（用户数据精度）：price/base_price/v1_price/v2_price 四列
  # scale 2→5；precision 8→12（整数位相应放宽）。PG change_column 2→5 位无损扩展
  def change
    change_column :prices, :price, :decimal, precision: 12, scale: 5
    change_column :prices, :base_price, :decimal, precision: 12, scale: 5
    change_column :prices, :v1_price, :decimal, precision: 12, scale: 5
    change_column :prices, :v2_price, :decimal, precision: 12, scale: 5
  end
end
