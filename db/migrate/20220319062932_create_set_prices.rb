class CreateSetPrices < ActiveRecord::Migration
  def change
    create_table :set_prices do |t|
      t.integer :item_id
      t.string :order_quantity
      t.decimal :price
      t.string :sell_by
      t.datetime :released_at

      t.timestamps null: false
    end
  end
end
