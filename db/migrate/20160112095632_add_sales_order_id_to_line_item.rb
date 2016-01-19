class AddSalesOrderIdToLineItem < ActiveRecord::Migration
  def change
    add_column :line_items, :sales_order_id, :integer
  end
end
