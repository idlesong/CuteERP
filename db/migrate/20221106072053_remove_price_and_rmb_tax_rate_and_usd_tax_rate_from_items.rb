class RemovePriceAndRmbTaxRateAndUsdTaxRateFromItems < ActiveRecord::Migration
  def change
    remove_column :items, :price, :decimal
    remove_column :items, :rmb_tax_rate, :decimal
    remove_column :items, :usd_tax_rate, :decimal
  end
end
