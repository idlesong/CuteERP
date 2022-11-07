class AddRemarkToSalesOrder < ActiveRecord::Migration
  def change
    add_column :sales_orders, :remark, :string
  end
end
