class RenameLineItemsPriceToFixedPrice < ActiveRecord::Migration
  def change
    rename_column :line_items, :price, :fixed_price
  end
end
