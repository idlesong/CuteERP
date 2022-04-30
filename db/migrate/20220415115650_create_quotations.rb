class CreateQuotations < ActiveRecord::Migration
  def change
    create_table :quotations do |t|
      t.string :quotation_number
      t.string :remark
      t.integer :customer_id

      t.timestamps null: false
    end
  end
end
