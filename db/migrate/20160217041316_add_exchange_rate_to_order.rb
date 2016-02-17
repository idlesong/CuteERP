class AddExchangeRateToOrder < ActiveRecord::Migration
  def change
    add_column :orders, :exchange_rate, :decimal, :precision => 8, :scale => 2
  end
end
