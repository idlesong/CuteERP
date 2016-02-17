class SalesOrdersController < ApplicationController
  # GET /sales_orders
  # GET /sales_orders.json
  def index
    @sales_orders = SalesOrder.all

    respond_to do |format|
      format.html # index.html.erb
      format.json { render json: @sales_orders }
    end
  end

  # GET /sales_orders/1
  # GET /sales_orders/1.json
  def show
    @sales_order = SalesOrder.find(params[:id])

    respond_to do |format|
      format.html # show.html.erb
      format.json { render json: @sales_order }
    end
  end

  # GET /sales_orders/new
  # GET /sales_orders/new.json
  def new
    @sales_order = SalesOrder.new

    # @orders = Order.all
    @customer = Customer.find( params[:customer_id])
    @orders = Order.where(customer_id: params[:customer_id])
    @cart = current_issue_cart

    @sales_order.customer = @customer
    @sales_order.payment_term = @customer.payment
    @sales_order.bill_contact   = @sales_order.ship_contact = @customer.contact
    @sales_order.bill_address   = @sales_order.ship_address = @customer.address
    @sales_order.bill_telephone = @sales_order.ship_telephone = @customer.telephone

    @sales_order.serial_number = @sales_order.generate_order_number

    respond_to do |format|
      format.html # new.html.erb
      format.json { render json: @sales_order }
    end
  end

  # GET /sales_orders/1/edit
  def edit
    @sales_order = SalesOrder.find(params[:id])
  end

  # GET /sales_orders/1/confirm
  def confirm
    @sales_order = SalesOrder.find(params[:id])
  end

  # POST /sales_orders
  # POST /sales_orders.json
  def create
    @sales_order = SalesOrder.new(params[:sales_order])
    @sales_order.add_line_items_from_issue_cart(current_issue_cart)

    current_issue_cart.line_items.each do |line|
      # logger.debug "=====refer_line_id== #{line.refer_line_id}"
      po_line = LineItem.find(line.refer_line_id)
      po_line.update_attribute(:quantity_issued, po_line.quantity_issued + line.quantity)
    end

    # @sales_order.customer_id = session[:customer_id]
    respond_to do |format|
      if @sales_order.save
        Cart.destroy(session[:issue_cart_id])
        session[:issue_cart_id] = nil
        format.html { redirect_to @sales_order, notice: 'Sales order was successfully created.' }
        format.json { render json: @sales_order, status: :created, location: @sales_order }
      else
        @orders = Order.where(customer_id: @sales_order.customer.id)
        @cart = current_issue_cart

        format.html { render action: "new" }
        format.json { render json: @sales_order.errors, status: :unprocessable_entity }
      end
    end
  end

  # PUT /sales_orders/1
  # PUT /sales_orders/1.json
  def update
    @sales_order = SalesOrder.find(params[:id])

    respond_to do |format|
      if @sales_order.update_attributes(params[:sales_order])
        format.html { redirect_to @sales_order, notice: 'Sales order was successfully updated.' }
        format.json { head :no_content }
      else
        format.html { render action: "edit" }
        format.json { render json: @sales_order.errors, status: :unprocessable_entity }
      end
    end
  end

  # DELETE /sales_orders/1
  # DELETE /sales_orders/1.json
  def destroy
    @sales_order = SalesOrder.find(params[:id])
    @sales_order.destroy

    respond_to do |format|
      format.html { redirect_to sales_orders_url }
      format.json { head :no_content }
    end
  end
end
