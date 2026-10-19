class AddSourceKeyToShipments < ActiveRecord::Migration[8.1]
  def change
    # 导入幂等键：六联单号|日期|快递号（重复导入按此整单重建行，Excel 为准）
    add_column :shipments, :source_key, :string
    add_index :shipments, :source_key
  end
end
