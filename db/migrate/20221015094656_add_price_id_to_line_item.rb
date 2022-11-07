class AddPriceIdToLineItem < ActiveRecord::Migration
  def change
    add_column :line_items, :price_id, :integer
  end
end
