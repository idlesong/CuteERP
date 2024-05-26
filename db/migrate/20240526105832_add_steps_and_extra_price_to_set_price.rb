class AddStepsAndExtraPriceToSetPrice < ActiveRecord::Migration
  def change
    add_column :set_prices, :step1, :decimal, :precision => 8, :scale => 2
    add_column :set_prices, :step2, :decimal, :precision => 8, :scale => 2
    add_column :set_prices, :step3, :decimal, :precision => 8, :scale => 2
    add_column :set_prices, :step4, :decimal, :precision => 8, :scale => 2
    add_column :set_prices, :step5, :decimal, :precision => 8, :scale => 2
    add_column :set_prices, :step6, :decimal, :precision => 8, :scale => 2
    add_column :set_prices, :step7, :decimal, :precision => 8, :scale => 2
    add_column :set_prices, :step8, :decimal, :precision => 8, :scale => 2
    add_column :set_prices, :step9, :decimal, :precision => 8, :scale => 2
    add_column :set_prices, :step10, :decimal, :precision => 8, :scale => 2
    add_column :set_prices, :step11, :decimal, :precision => 8, :scale => 2
    add_column :set_prices, :step12, :decimal, :precision => 8, :scale => 2
    add_column :set_prices, :step13, :decimal, :precision => 8, :scale => 2
    add_column :set_prices, :step14, :decimal, :precision => 8, :scale => 2
    add_column :set_prices, :step15, :decimal, :precision => 8, :scale => 2
    add_column :set_prices, :step16, :decimal, :precision => 8, :scale => 2    
    add_column :set_prices, :extra_price, :decimal, :precision => 8, :scale => 2 
  end
end
