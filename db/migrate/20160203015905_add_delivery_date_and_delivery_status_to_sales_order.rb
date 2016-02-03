class AddDeliveryDateAndDeliveryStatusToSalesOrder < ActiveRecord::Migration
  def change
    add_column :sales_orders, :delivery_date, :datetime
    add_column :sales_orders, :delivery_status, :string
  end
end
