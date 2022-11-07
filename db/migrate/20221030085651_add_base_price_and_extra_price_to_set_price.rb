class AddBasePriceAndExtraPriceToSetPrice < ActiveRecord::Migration
  def change
    add_column :set_prices, :base_price, :decimal, :precision => 8, :scale => 2
    add_column :set_prices, :extra_price, :decimal, :precision => 8, :scale => 2
  end
end
