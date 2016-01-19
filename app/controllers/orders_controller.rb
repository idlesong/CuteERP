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
    @customers = Customer.all

    if params[:customer_id]
      # logger.debug "=====customer_id== #{params[:customer_id]}"
      session[:customer_id] = params[:customer_id]
      @customer  = Customer.find(params[:customer_id])
      # logger.debug "=====customer== #{@customer}"
    else
      @customer = Customer.first
      session[:customer_id] = @customer.id
    end

    # initialize orders with customer selected customer
    @order = Order.new
    @order.customer = @customer

    # set bill_to and ship_to contact by default, then confirm it in sales order
    @order.name      = @order.ship_contact = @customer.contact
    @order.address   = @order.ship_address = @customer.address
    @order.telephone = @order.ship_telephone = @customer.telephone
    @order.pay_type = @customer.payment
    # bill_to = @customer.contacts.find_by_note("bill_to") if @customer.contacts.where(note: "bill_to").exists?
    # ship_to = @customer.contacts.find_by_note("ship_to") if @customer.contacts.where(note: "ship_to").exists?

    @cart = current_cart
    if @cart.line_items.empty?
      #redirect_to inventory_url, :notice => "Your cart is empty"
      #return
    end

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

    #
    @cart = Cart.create
    @cart.line_items = @order.line_items
    if @cart.line_items.empty?
      #redirect_to inventory_url, :notice => "Your cart is empty"
      #return
    end
  end

  # POST /orders
  # POST /orders.json
  def create
    @order = Order.new(params[:order])
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
        format.html { render action: "new" }
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
    @order.destroy

    respond_to do |format|
      format.html { redirect_to orders_url }
      format.json { head :no_content }
    end
  end
end
