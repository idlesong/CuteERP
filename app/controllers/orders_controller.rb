class OrdersController < ApplicationController
  skip_before_filter :authorize, :only => [:new, :create]

  # GET /orders
  # GET /orders.json
  def index
    @orders = Order.all

    respond_to do |format|
      format.html # index.html.erb
      format.json { render json: @orders }

      format.csv { send_data @orders.export_to_csv }
      format.xls { send_data @orders.export_to_csv(col_sep: "\t") }      
    end
  end

  # GET /orders/1
  # GET /orders/1.json
  def show
    @order = Order.find(params[:id])

    @end_customer = Customer.find(@order.end_customer_id) if not @order.end_customer_id.nil?

    respond_to do |format|
      format.html # show.html.erb
      format.json { render json: @order }
    end
  end


  # GET /orders/new
  # GET /orders/new.json
  def new
    # customers with active prices? (available)
    @customers = Customer.joins(:prices).where(prices: {status: "active"}).uniq.where("credit > ?", 0)

    # clear cart and destroy associated line_items, when customer switched
    if (params[:customer_id] && (params[:customer_id] != current_customer.id))
      session[:customer_id] = params[:customer_id]
      current_cart.line_items.clear
    end

    @customer = current_customer
    # initialize orders with selected customer
    @order = Order.new
    @order.initialize_order_header(current_customer)
    @order.exchange_rate = monthly_exchange_rate

    @cart = current_cart
    @cart.line_items.clear
    # @order.exchange_rate = @exchange_rate_setting.value.to_i if @exchange_rate_setting.value.to_f > 0
    session[:cart_order_type] = "Order"
    session[:cart_currency] = @order.customer.currency
    # session[:exchange_rate] = @order.exchange_rate

    respond_to do |format|
      format.html # new.html.erb
      format.json { render json: @order }
      # format.js
    end
  end

  # Get /orders/reverse?customer_id=1
  def reverse

    # initialize orders with selected customer
    if params[:customer_id]
      @customer = Customer.find( params[:customer_id])
    else
      @customer = current_customer
    end
    @orders = Order.where(customer_id: @customer.id)

    @order = Order.new
    @order.initialize_order_header(current_customer)
    @order.exchange_rate = monthly_exchange_rate

    @cart = current_cart
    @cart.line_items.clear
    # @order.exchange_rate = @exchange_rate_setting.value.to_i if @exchange_rate_setting.value.to_f > 0
    session[:cart_order_type] = "Order"
    session[:cart_currency] = @order.customer.currency
    # session[:exchange_rate] = @order.exchange_rate

    respond_to do |format|
      format.html # new.html.erb
      format.json { render json: @order }
      # format.js
    end
  end

  # GET /orders/1/edit
  def edit
    @order = Order.find(params[:id])
    @customer = current_customer

    if @order.not_issued?
      # @main_items = Item.where(assembled: ['no','yes'])
      # @option_items = Item.where(assembled: 'addition')
      # @customers = Customer.where("credit > ?", 0)

      # customers with active prices? (available)
      @customers = Customer.joins(:prices).where(prices: {status: "active"}).uniq.where("credit > ?", 0)      

      @cart = current_cart
      @cart.copy_line_items_from_customer_order(@order)
      # @cart.line_items.clear
      # @order.line_items.each do |line|
      #   new_line = line.dup
      #   new_line.line = nil
      #   new_line.line_number = 'cart' + new_line.line_number # must uniq
      #   @cart.line_items << new_line
      # end

      session[:cart_order_type] = "Order"
      session[:cart_currency] = @order.customer.currency
      # session[:exchange_rate] = @order.exchange_rate
    end

    respond_to do |format|
      if @order.not_issued?
        format.html 
        format.json
      else
        format.html { redirect_to @order, notice: 'Can not edit this order, order been issued!'}
        format.json { render json: @order.errors, status: :unprocessable_entity }
      end
    end
  end

  # POST /orders
  # POST /orders.json
  def create
    @order = Order.new(params[:order])

    if current_cart.line_items.exists? 
      @order.add_line_items_from_cart(current_cart, params["reverse_order"]) 
    end

    respond_to do |format|
      if @order.save
        Cart.destroy(session[:cart_id])
        session[:cart_id] = nil
        format.html { redirect_to @order, notice: 'Order was created.' }
        format.js
        # format.json { render json: @order }
      else
        @main_items = Item.where(assembled: ['no','yes'])
        @option_items = Item.where(assembled: 'addition')

        @customer = current_customer
        @customers = Customer.all
        @cart = current_cart

        format.html { render action: "new", notice: 'Errors when save order.' }
        format.js
        # format.json { render json: @order }
      end
    end
  end

  # PUT /orders/1
  # PUT /orders/1.json
  def update
    @order = Order.find(params[:id])

    respond_to do |format|
      if current_cart.line_items.exists?  # can't update without cart.line_items
        if @order.update_attributes(params[:order])
          @order.line_items.clear
          @order.add_line_items_from_cart(current_cart, params['reverse_order'])

          format.html { redirect_to @order, notice: 'Order was successfully updated.' }
          format.json { head :no_content }
        end
      else
        # logger.debug "========Errors when update order==== #{@cart}"
        @customer = current_customer
        @cart = current_cart
        format.html { render action: "edit", notice: 'Errors when update order, make sure line_items.' }
        format.json { render json: @order.errors, status: :unprocessable_entity }
      end
    end
  end

  def import
    Order.import(params[:file])
    redirect_to orders_url, notice: "Orders imported."
  end

  # DELETE /orders/1
  # DELETE /orders/1.json
  def destroy
    @order = Order.find(params[:id])
    # @order.destroy

    respond_to do |format|
      if @order.destroy
        format.html { redirect_to orders_url }
        format.json { head :no_content }
      else
        format.html { redirect_to order_url(@order), :notice => "Can not destroy, this order has been issued!" }
        format.json { head :no_content }
      end
    end
  end
end
