class AddRmbTaxRateAndUsdTaxRateToItem < ActiveRecord::Migration
  def change
    add_column :items, :rmb_tax_rate, :decimal, :precision => 8, :scale => 2, :default => 0.17
    add_column :items, :usd_tax_rate, :decimal, :precision => 8, :scale => 2, :default => 0
  end
end
