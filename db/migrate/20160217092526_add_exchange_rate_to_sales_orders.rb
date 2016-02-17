class AddExchangeRateToSalesOrders < ActiveRecord::Migration
  def change
    add_column :sales_orders, :exchange_rate, :decimal, :precision => 8, :scale => 2
  end
end
