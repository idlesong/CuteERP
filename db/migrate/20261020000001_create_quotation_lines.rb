class CreateQuotationLines < ActiveRecord::Migration[8.1]
  def change
    # 报价单明细：生成时从所选价格快照（价格可复用于多张报价单，单据不随后续调价漂移）
    create_table :quotation_lines do |t|
      t.references :quotation, null: false, foreign_key: true
      t.references :price, foreign_key: true
      t.string :part_number
      t.string :product_name
      t.decimal :unit_price, precision: 8, scale: 2
      t.string :condition
      t.string :currency, default: "RMB"
      t.string :remark
      t.timestamps
    end
  end
end
