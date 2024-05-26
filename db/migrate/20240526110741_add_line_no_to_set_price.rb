class AddLineNoToSetPrice < ActiveRecord::Migration
  def change
    add_column :set_prices, :line_no, :integer
  end
end
