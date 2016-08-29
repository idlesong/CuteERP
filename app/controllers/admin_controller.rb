class AdminController < ApplicationController
  def index
  	@total_orders = Order.count

    this_year = Time.now.beginning_of_year..Time.now
    @orders = Order.where(created_at: this_year)
    @sales_orders = SalesOrder.where(created_at: this_year).order("delivery_date IS NULL, delivery_date ASC")

    this_month = Time.now.beginning_of_month..Time.now
    last_month = 1.month.ago.beginning_of_month..Time.now.beginning_of_month
    this_quarter = Time.now.beginning_of_quarter..Time.now
    last_quarter_begin = (Time.now.beginning_of_quarter - 1.day).beginning_of_quarter
    last_quarter = last_quarter_begin .. Time.now.beginning_of_quarter
    last_2nd_quarter = (last_quarter_begin - 1.day).beginning_of_quarter .. last_quarter_begin
    last_3rd_quarter = ((last_quarter_begin - 1.day).beginning_of_quarter - 1.day).beginning_of_quarter .. (last_quarter_begin-1.day).beginning_of_quarter
    last_year = (Time.now.beginning_of_year - 1.day).beginning_of_year .. Time.now.beginning_of_year

    @last_month_line_items = LineItem.joins("INNER JOIN sales_orders ON line_items.line_id = sales_orders.id ")
                                .where(line_items: {line_type: 'SalesOrder'})
                                .where(sales_orders: {delivery_date: last_month} )

    @this_month_line_items = LineItem.joins("INNER JOIN sales_orders ON line_items.line_id = sales_orders.id ")
                                .where(line_items: {line_type: 'SalesOrder'})
                                .where(sales_orders: {delivery_date: this_month} )

    @this_quarter_line_items = LineItem.joins("INNER JOIN sales_orders ON line_items.line_id = sales_orders.id ")
                                .where(line_items: {line_type: 'SalesOrder'})
                                .where(sales_orders: {delivery_date: this_quarter} )

    @last_quarter_line_items = LineItem.joins("INNER JOIN sales_orders ON line_items.line_id = sales_orders.id ")
                                .where(line_items: {line_type: 'SalesOrder'})
                                .where(sales_orders: {delivery_date: last_quarter} )

    @last_2nd_quarter_line_items = LineItem.joins("INNER JOIN sales_orders ON line_items.line_id = sales_orders.id ")
                                .where(line_items: {line_type: 'SalesOrder'})
                                .where(sales_orders: {delivery_date: last_2nd_quarter} )

    @last_3rd_quarter_line_items = LineItem.joins("INNER JOIN sales_orders ON line_items.line_id = sales_orders.id ")
                                .where(line_items: {line_type: 'SalesOrder'})
                                .where(sales_orders: {delivery_date: last_3rd_quarter} )

    @this_year_line_items = LineItem.joins("INNER JOIN sales_orders ON line_items.line_id = sales_orders.id ")
                                .where(line_items: {line_type: 'SalesOrder'})
                                .where(sales_orders: {delivery_date: this_year} )

    @last_year_line_items = LineItem.joins("INNER JOIN sales_orders ON line_items.line_id = sales_orders.id ")
                                .where(line_items: {line_type: 'SalesOrder'})
                                .where(sales_orders: {delivery_date: last_year} )

    # @items = Item.all
    # @option_items = Item.where(:package => 'software')
    # @main_items = @items - @option_items
    @main_items = Item.where(assembled: ['no','yes']).order("partNo ASC")
    @option_items = Item.where(assembled: 'addition').order("partNo ASC")
  end
end
