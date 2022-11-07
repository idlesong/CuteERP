class AddBasePriceAndExtraPriceToPrice < ActiveRecord::Migration
  def change
    add_column :prices, :base_price, :decimal, :precision => 8, :scale => 2
    add_column :prices, :extra_price, :decimal, :precision => 8, :scale => 2
  end
end
