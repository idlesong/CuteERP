class AdminController < ApplicationController
  def index
  	@total_orders = Order.count

    this_year = Time.now.beginning_of_year..Time.now
    @orders = Order.order(:name).where(created_at: this_year)
    @sales_orders = SalesOrder.where(created_at: this_year).order("delivery_date IS NULL, delivery_date ASC")
    @open_orders = Order.order(:name)

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

    # create a yearly forecast table, by unique prices 
    this_financial_year = this_financial_year_begin .. (Time.now.end_of_year + 1.day).at_end_of_quarter
    @forecast_all_line_items       = LineItem.joins("INNER JOIN sales_orders ON line_items.line_id = sales_orders.id ")
                                     .where(line_items: {line_type: 'SalesOrder'})
                                     .where(sales_orders: {delivery_date: this_financial_year} )  
    @forecast_shipped_line_items   = LineItem.joins("INNER JOIN sales_orders ON line_items.line_id = sales_orders.id ")
                                     .where(line_items: {line_type: 'SalesOrder'})
                                     .where(sales_orders: {delivery_date: this_financial_year} )
    @forecast_plan_ship_line_items = LineItem.joins("INNER JOIN sales_orders ON line_items.line_id = sales_orders.id ")
                                     .where(line_items: {line_type: 'SalesOrder'})
                                     .where(sales_orders: {delivery_plan: this_financial_year} )                                 

    # @forecast_uniq_prices = @forecast_shipped_line_items.select(:price_id).distinct                                 

    # create Sales Rolling Forecast
    # featch uniq prices
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

    # create Sales Rolling Forecast table
    financial_months = Array.new()
    month_begin = Time.now.beginning_of_year.at_end_of_quarter + 1.day
    for n in 0..11
      financial_months[n] =  month_begin .. month_begin.at_end_of_month
      month_begin = month_begin.at_end_of_month + 1.day
    end
    
    forecast_table_by_month = Array.new(12) {Array.new(@yearly_uniq_prices.length) }
    financial_months.each_with_index do | month, index |
      @yearly_uniq_prices.each_with_index do | price, pn |
        if index < 7  
          @month_line_items = LineItem.joins("INNER JOIN sales_orders ON line_items.line_id = sales_orders.id ")
            .where(line_items: {line_type: 'SalesOrder'})
            .where(sales_orders: {delivery_plan: month})
          
          forecast_table_by_month[index][pn] = @month_line_items.where(price_id: price).sum("quantity")
        else
          @plan_ship_line_items = LineItem.joins("INNER JOIN sales_orders ON line_items.line_id = sales_orders.id ")
            .where(line_items: {line_type: 'SalesOrder'})
            .where(sales_orders: {delivery_plan: month})
      
          forecast_table_by_month[index][pn] = @plan_ship_line_items.where(price_id: price).sum("quantity")  
        end
      end
    end
    
    @forecast_table = forecast_table_by_month.transpose

    # create Product Rolling Forecast
    # 1. featch uniq_items
    uniq_items = Array.new()
    @forecast_all_line_items.select(:item_id).distinct.each do | line_item |
        uniq_items.push(line_item.item_id)
    end

    @yearly_uniq_items = Item.where(id: uniq_items)   

    # 2. create Product Rolling Forecast table
    financial_months = Array.new()
    month_begin = Time.now.beginning_of_year.at_end_of_quarter + 1.day
    for n in 0..11
      financial_months[n] =  month_begin .. month_begin.at_end_of_month
      month_begin = month_begin.at_end_of_month + 1.day
    end
    
    item_forecast_table_by_month = Array.new(12) {Array.new(@yearly_uniq_items.length) }
    financial_months.each_with_index do | month, index |
      @yearly_uniq_items.each_with_index do | item, pn |

          @year_table_line_items = LineItem.joins("INNER JOIN sales_orders ON line_items.line_id = sales_orders.id ")
            .where(line_items: {line_type: 'SalesOrder'})
            .where(sales_orders: {delivery_plan: month})
      
          item_forecast_table_by_month[index][pn] = @year_table_line_items.where(item_id: item).sum("quantity")  

      end
    end
    
    @item_forecast_table = item_forecast_table_by_month.transpose

  end

  # private
  #   def financial_nth_month(n)
  #     nth_month_line_items = LineItem.joins("INNER JOIN sales_orders ON line_items.line_id = sales_orders.id ")
  #     .where(line_items: {line_type: 'SalesOrder'})
  #     .where(sales_orders: {delivery_date: this_month} )   
  #   end
end
