class AddQuantityIssuedToLineItem < ActiveRecord::Migration
  def change
    add_column :line_items, :quantity_issued, :integer, :default => 0
  end
end
