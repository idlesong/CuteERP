class AddDeliveryPlanToSalesOrder < ActiveRecord::Migration
  def change
    add_column :sales_orders, :delivery_plan, :datetime
  end
end
