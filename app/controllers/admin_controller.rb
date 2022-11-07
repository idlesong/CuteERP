class AdminController < ApplicationController
  def index
  	@total_orders = Order.count

    this_year = Time.now.beginning_of_year..Time.now
    @orders = Order.order(:name).where(created_at: this_year)
    @sales_orders = SalesOrder.where(created_at: this_year).order("delivery_date IS NULL, delivery_date ASC")

    this_month = Time.now.beginning_of_month..Time.now
    last_month = 1.month.ago.beginning_of_month..Time.now.beginning_of_month
    this_quarter = Time.now.beginning_of_quarter..Time.now
    last_quarter_begin = (Time.now.beginning_of_quarter - 1.day).beginning_of_quarter
    last_quarter = last_quarter_begin .. Time.now.beginning_of_quarter
    last_2nd_quarter = (last_quarter_begin - 1.day).beginning_of_quarter .. last_quarter_begin
    last_3rd_quarter = ((last_quarter_begin - 1.day).beginning_of_quarter - 1.day).beginning_of_quarter .. (last_quarter_begin-1.day).beginning_of_quarter
    last_year = (Time.now.beginning_of_year - 1.day).beginning_of_year .. Time.now.beginning_of_year

    this_financial_year_begin = Time.now.beginning_of_year.at_end_of_quarter + 1.day
      
    april_begin = this_financial_year_begin
    may_begin = april_begin.at_end_of_month + 1.day
    june_begin = may_begin.at_end_of_month + 1.day

    july_begin = this_financial_year_begin.at_end_of_quarter + 1.day
    auguest_begin = july_begin.at_end_of_month + 1.day
    september_begin = auguest_begin.at_end_of_month + 1.day

    # create a yearly forecast table, by prices 
    this_financial_year = this_financial_year_begin .. (Time.now.end_of_year + 1.day).at_end_of_quarter
    @forecast_all_line_items = LineItem.joins("INNER JOIN sales_orders ON line_items.line_id = sales_orders.id ")
                                     .where(line_items: {line_type: 'SalesOrder'})
                                     .where(sales_orders: {delivery_date: this_financial_year} )  
    @forecast_shipped_line_items = LineItem.joins("INNER JOIN sales_orders ON line_items.line_id = sales_orders.id ")
                                     .where(line_items: {line_type: 'SalesOrder'})
                                     .where(sales_orders: {delivery_date: this_financial_year} )
    @forecast_plan_ship_line_items = LineItem.joins("INNER JOIN sales_orders ON line_items.line_id = sales_orders.id ")
                                     .where(line_items: {line_type: 'SalesOrder'})
                                     .where(sales_orders: {delivery_plan: this_financial_year} )                                 

    # @forecast_uniq_prices = @forecast_shipped_line_items.select(:price_id).distinct                                 

    uniq_prices = Array.new()
    @forecast_shipped_line_items.select(:price_id).distinct.each do | line_item |
        uniq_prices.push(line_item.price_id)
    end
    
    @forecast_plan_ship_line_items.select(:price_id).distinct.each do | line_item |
      unless uniq_prices.include?(line_item.price_id)
        uniq_prices.push(line_item.price_id)
      end
    end

    @yearly_uniq_prices = Price.where(id: uniq_prices)

    # uniq_prices = Array.new()    
    # # @forecast_all_line_items.select(:price_id).distinct.each do | line_item |                                 
    # @forecast_all_line_items.select(:price_id).distinct.each do | line_item |
    #   uniq_prices.push(line_item.price_id) 
    # end

    # financial_months = Array.new()
    # financial_months.each do | n |
    #   financial_months[n] = this_financial_year_begin.at_end_of_month + 1.day
    # end

    # forecast_table = Array.new(uniq_prices.length) {Array.new(12)}
    # financial_months.each do | month |
    #   uniq_prices.each do | n |
    #     forecast_table[month][n] = @forecast_all_line_items.where(uniq_prices[n]).where(delivery_date: month).sum("quantity")
    #   end
    # end


    @this_year_open_order_line_items = LineItem.joins("INNER JOIN sales_orders ON line_items.line_id = sales_orders.id ")
                                     .where(line_items: {line_type: 'SalesOrder'})
                                     .where(sales_orders: {delivery_date: this_year} )

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
                                                      

    # select sales orders of current FY, group by "item_id", "price", "customer_id", sum by deliver_date                                
    # join customer_id into table first?

    @april_line_items = LineItem.joins("INNER JOIN sales_orders ON line_items.line_id = sales_orders.id ")
    .where(line_items: {line_type: 'SalesOrder'})
    .where(sales_orders: {delivery_date: april_begin.all_month} )

    @september_line_items = LineItem.joins("INNER JOIN sales_orders ON line_items.line_id = sales_orders.id ")
    .where(line_items: {line_type: 'SalesOrder'})
    .where(sales_orders: {delivery_date: september_begin.all_month} )
    # .find(:all, 
    #       :select => "item_id, line_id, sum(quantity) AS sum_forecast_quantity",
    #       :group => "item_id, line_id")
    # .select("item_id, line_id, sum(quantity) AS sum_forecast_quantity").group("item_id, line_id")

    
    # @sales_orders = SalesOrder

    # @items = Item.all
    # @option_items = Item.where(:package => 'software')
    # @main_items = @items - @option_items
    #
    # Item default_scope { where order: 'name'}

    # @main_items = Item.where(assembled: ['no','main', assembled]).order("partNo ASC")
    @main_items = Item.order('name').where(assembled: ['no','main', 'assembled'])
    #  @option_items = Item.where(assembled: 'addition').order("partNo ASC")
    @option_items = Item.where(assembled: 'addition').order("partNo ASC")


  end

  # private
  #   def financial_nth_month(n)
  #     nth_month_line_items = LineItem.joins("INNER JOIN sales_orders ON line_items.line_id = sales_orders.id ")
  #     .where(line_items: {line_type: 'SalesOrder'})
  #     .where(sales_orders: {delivery_date: this_month} )   
  #   end
end
