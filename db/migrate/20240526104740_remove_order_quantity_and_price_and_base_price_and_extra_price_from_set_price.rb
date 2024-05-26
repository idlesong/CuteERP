class RemoveOrderQuantityAndPriceAndBasePriceAndExtraPriceFromSetPrice < ActiveRecord::Migration
  def change
    remove_column :set_prices, :order_quantity, :string
    remove_column :set_prices, :price, :decimal
    remove_column :set_prices, :base_price, :decimal
    remove_column :set_prices, :extra_price, :decimal
  end
end
