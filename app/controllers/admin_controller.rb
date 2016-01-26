class AdminController < ApplicationController
  def index
  	@total_orders = Order.count

    @orders = Order.all
    @sales_orders = SalesOrder.all    
  end
end
