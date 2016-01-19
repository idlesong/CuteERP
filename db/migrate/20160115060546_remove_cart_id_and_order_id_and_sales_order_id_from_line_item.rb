class RemoveCartIdAndOrderIdAndSalesOrderIdFromLineItem < ActiveRecord::Migration
  def up
    remove_column :line_items, :cart_id
    remove_column :line_items, :order_id
    remove_column :line_items, :sales_order_id
  end

  def down
    add_column :line_items, :sales_order_id, :integer
    add_column :line_items, :order_id, :integer
    add_column :line_items, :cart_id, :integer
  end
end
