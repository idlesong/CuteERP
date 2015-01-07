class CreatePrices < ActiveRecord::Migration
  def change
    create_table :prices do |t|
      t.integer :item_id
      t.integer :customer_id
      t.decimal :price
      t.string :payment_terms
      t.string :condition
      t.string :sales_suggestion
      t.string :department_suggestion
      t.string :finance_suggestion
      t.string :boss_suggestion

      t.timestamps
    end
  end
end
