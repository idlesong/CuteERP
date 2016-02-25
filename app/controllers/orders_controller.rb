class OrdersController < ApplicationController
  skip_before_filter :authorize, :only => [:new, :create]

  # GET /orders
  # GET /orders.json
  def index
    @orders = Order.all

    respond_to do |format|
      format.html # index.html.erb
      format.json { render json: @orders }
    end
  end

  # GET /orders/1
  # GET /orders/1.json
  def show
    @order = Order.find(params[:id])

    respond_to do |format|
      format.html # show.html.erb
      format.json { render json: @order }
    end
  end

  # GET /orders/new
  # GET /orders/new.json
  def new
    @items = Item.all
    @option_items = Item.where(:package => 'software')
    @main_items = @items - @option_items
    @customers = Customer.all

    # switch current customer, clear cart and destroy associated line_items
    if (params[:customer_id] && (params[:customer_id] != current_customer.id))
      session[:customer_id] = params[:customer_id]
      current_cart.line_items.clear
    end

    @customer = current_customer
    # initialize orders with selected customer
    @order = Order.new
    @order.initialize_order_header(current_customer)

    @cart = current_cart
    session[:cart_order_type] = "Order"
    session[:cart_currency] = @order.customer.currency
    session[:exchange_rate] = @order.exchange_rate

    respond_to do |format|
      format.html # new.html.erb
      # format.json { render json: @order }
      format.js
    end
  end

  # GET /orders/1/edit
  def edit
    @order = Order.find(params[:id])

    @items = Item.all
    @customers = Customer.all

    @cart = current_cart
    @cart.line_items = @order.line_items

    session[:cart_order_type] = "Order"
    session[:cart_currency] = @order.customer.currency
    session[:exchange_rate] = @order.exchange_rate
  end

  # POST /orders
  # POST /orders.json
  def create
    @order = Order.new(params[:order]) if @order.nil?
    @order.add_line_items_from_cart(current_cart)
    @order.customer_id = session[:customer_id]

    respond_to do |format|
      if @order.save
        Cart.destroy(session[:cart_id])
        session[:cart_id] = nil
        format.html { redirect_to @order, notice: 'Order was created.' }
        format.js
        # format.json { render json: @order }
      else
        @items = Item.all
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
    @order.add_line_items_from_cart(current_cart)

    respond_to do |format|
      if @order.update_attributes(params[:order])
        format.html { redirect_to @order, notice: 'Order was successfully updated.' }
        format.json { head :no_content }
      else
        format.html { render action: "edit" }
        format.json { render json: @order.errors, status: :unprocessable_entity }
      end
    end
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
        format.html { redirect_to order_url(@order), :notice => "Order can't destroyed" }
        format.json { head :no_content }
      end
    end
  end
end
