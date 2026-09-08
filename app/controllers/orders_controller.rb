class OrdersController < ApplicationController
  skip_before_action :authorize, only: [:new, :create]

  before_action :set_order, only: [:show, :edit, :update, :destroy]

  # GET /orders
  def index
    @orders = Order.all

    respond_to do |format|
      format.html
      format.json { render json: @orders }

      format.csv { send_data @orders.export_to_csv }
      format.xls { send_data @orders.export_to_csv(col_sep: "\t") }
    end
  end

  # GET /orders/1
  def show
    @end_customer = Customer.find(@order.end_customer_id) unless @order.end_customer_id.nil?

    respond_to do |format|
      format.html
      format.json { render json: @order }
    end
  end

  # GET /orders/new
  def new
    # customers with active prices (available)
    @customers = Customer.joins(:prices).where(prices: { status: "active" }).distinct.where("credit > ?", 0)

    # clear cart and destroy associated line_items, when customer switched
    if params[:customer_id] && (params[:customer_id] != current_customer.id.to_s)
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
    session[:cart_order_type] = "Order"
    session[:cart_currency] = @order.customer.currency

    respond_to do |format|
      format.html
      format.json { render json: @order }
    end
  end

  # GET /orders/reverse?customer_id=1
  def reverse
    # initialize orders with selected customer
    @customer = params[:customer_id] ? Customer.find(params[:customer_id]) : current_customer
    @orders = Order.where(customer_id: @customer.id)

    @order = Order.new
    @order.initialize_order_header(current_customer)
    @order.exchange_rate = monthly_exchange_rate

    @cart = current_cart
    @cart.line_items.clear
    session[:cart_order_type] = "Order"
    session[:cart_currency] = @order.customer.currency

    respond_to do |format|
      format.html
      format.json { render json: @order }
    end
  end

  # GET /orders/1/edit
  def edit
    @customer = current_customer

    if @order.not_issued?
      # customers with active prices (available)
      @customers = Customer.joins(:prices).where(prices: { status: "active" }).distinct.where("credit > ?", 0)

      @cart = current_cart
      @cart.copy_line_items_from_customer_order(@order)

      session[:cart_order_type] = "Order"
      session[:cart_currency] = @order.customer.currency
    end

    respond_to do |format|
      if @order.not_issued?
        format.html
        format.json
      else
        format.html { redirect_to @order, notice: "Can not edit this order, order been issued!" }
        format.json { render json: @order.errors, status: :unprocessable_entity }
      end
    end
  end

  # POST /orders
  def create
    @order = Order.new(order_params)

    if current_cart.line_items.exists?
      @order.add_line_items_from_cart(current_cart, params["reverse_order"])
    end

    respond_to do |format|
      if @order.save
        Cart.destroy(session[:cart_id])
        session[:cart_id] = nil
        format.html { redirect_to @order, notice: "Order was created." }
        format.js
      else
        @main_items = Item.where(assembled: %w[no yes])
        @option_items = Item.where(assembled: "addition")

        @customer = current_customer
        @customers = Customer.all
        @cart = current_cart

        format.html { render action: "new", notice: "Errors when save order." }
        format.js
      end
    end
  end

  # PATCH/PUT /orders/1
  def update
    respond_to do |format|
      if current_cart.line_items.exists? # can't update without cart.line_items
        if @order.update(order_params)
          @order.line_items.clear
          @order.add_line_items_from_cart(current_cart, params["reverse_order"])

          format.html { redirect_to @order, notice: "Order was successfully updated." }
          format.json { head :no_content }
        end
      else
        @customer = current_customer
        @cart = current_cart
        format.html { render action: "edit", notice: "Errors when update order, make sure line_items." }
        format.json { render json: @order.errors, status: :unprocessable_entity }
      end
    end
  end

  # POST /orders/import
  def import
    Order.import(params[:file])
    redirect_to orders_url, notice: "Orders imported."
  end

  # DELETE /orders/1
  def destroy
    respond_to do |format|
      if @order.destroy
        format.html { redirect_to orders_url }
        format.json { head :no_content }
      else
        format.html { redirect_to order_url(@order), notice: "Can not destroy, this order has been issued!" }
        format.json { head :no_content }
      end
    end
  end

  private

  def set_order
    @order = Order.find(params[:id])
  end

  def order_params
    params.require(:order).permit(:customer_id, :order_number, :name, :address, :telephone,
                                  :ship_contact, :ship_address, :ship_telephone, :pay_type,
                                  :exchange_rate, :remark, :end_customer_id, :po_number)
  end
end
