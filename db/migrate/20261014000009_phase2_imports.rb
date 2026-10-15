# 第二阶段 2.2：导入批次记录 + 六联单行批量标记
class Phase2Imports < ActiveRecord::Migration[8.1]
  def up
    create_table :imports do |t|
      t.string :kind, null: false                 # customer_orders / sales_orders
      t.date :month
      t.string :filename
      t.references :imported_by, null: false      # users
      t.jsonb :stats, default: {}
      t.timestamps
    end
    add_column :production_lines, :source, :string, default: "manual" # manual / batch
  end

  def down
    drop_table :imports
    remove_column :production_lines, :source
  end
end
