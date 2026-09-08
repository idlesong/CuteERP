class SalesOrdersController < ApplicationController
  before_action :set_sales_order, only: [:show, :edit, :update, :destroy,
                                         :production, :edit_production, :confirm, :invoice, :packing_list]

  # GET /sales_orders
  def index
    @sales_orders = SalesOrder.all

    respond_to do |format|
      format.html
      format.json { render json: @sales_orders }
    end
  end

  # GET /sales_orders/1
  def show
    respond_to do |format|
      format.html
      format.json { render json: @sales_order }
    end
  end

  # GET /sales_orders/new
  def new
    @sales_order = SalesOrder.new

    @customer = Customer.find(params[:customer_id])
    @orders = Order.where(customer_id: params[:customer_id])

    @sales_order.initialize_order_header(@customer)
    @sales_order.exchange_rate = monthly_exchange_rate

    @cart = current_issue_cart
    @cart.line_items.clear

    respond_to do |format|
      format.html
      format.json { render json: @sales_order }
    end
  end

  # GET /sales_orders/1/edit
  def edit
    @orders = Order.where(customer_id: @sales_order.customer_id)

    @cart = current_issue_cart
    @cart.copy_line_items_from_sales_order(@sales_order)

    session[:cart_order_type] = "SalesOrder"
    session[:cart_currency] = @sales_order.customer.currency
    session[:exchange_rate] = @sales_order.exchange_rate

    respond_to do |format|
      format.html
      format.json
    end
  end

  # GET /sales_orders/1/production
  def production
    respond_to do |format|
      format.html
      format.json { render json: @sales_order }
    end
  end

  # GET /sales_orders/1/edit_production
  def edit_production
    respond_to do |format|
      format.html
      format.json { render json: @sales_order }
    end
  end

  # POST /sales_orders
  def create
    @sales_order = SalesOrder.new(sales_order_params)
    @sales_order.add_line_items_from_issue_cart(current_issue_cart)

    respond_to do |format|
      if @sales_order.save
        @sales_order.issue_refer_line_items

        Cart.destroy(session[:issue_cart_id])
        session[:issue_cart_id] = nil

        format.html { redirect_to @sales_order, notice: "Sales order was successfully created." }
        format.json { render json: @sales_order, status: :created, location: @sales_order }
      else
        @orders = Order.where(customer_id: @sales_order.customer.id)
        @cart = current_issue_cart

        session[:cart_order_type] = "SalesOrder"
        session[:cart_order_id] = @sales_order.id

        format.html { render action: "new" }
        format.json { render json: @sales_order.errors, status: :unprocessable_entity }
      end
    end
  end

  # PATCH/PUT /sales_orders/1
  def update
    # update delivery_status only (includes reschedule delivery_plan)
    if params.dig(:sales_order, :delivery_status)
      logger.debug "==####==update delivery status= #{params[:sales_order][:delivery_status]}"
    else
      # skip when cart is empty.
      if current_issue_cart.line_items.exists?
        logger.debug "==####==current_issue_cart_has_line_items="
        @sales_order.issue_unissue_po_line_items_when_so_and_cart_diffs(current_issue_cart)

        @sales_order.line_items.clear
        @sales_order.add_line_items_from_issue_cart(current_issue_cart)

        @sales_order.save
      end

      # confirm_and_dispatch_order if delivery_date exist
      if params[:sales_order][:"delivery_date(1i)"]
        delivery_plan = Time.zone.local(params[:sales_order][:"delivery_date(1i)"].to_i,
                                        params[:sales_order][:"delivery_date(2i)"].to_i,
                                        params[:sales_order][:"delivery_date(3i)"].to_i)
        logger.debug "==####==confirm and dispatch: delivery_plan= #{delivery_plan}"

        @sales_order.update_attribute(:delivery_plan, delivery_plan + 8.hours)
      end
      @sales_order.save
    end

    respond_to do |format|
      if @sales_order.update(sales_order_params)
        format.html { redirect_to @sales_order, notice: "Sales order was successfully updated." }
        format.json { head :no_content }
      else
        @orders = Order.where(customer_id: @sales_order.customer.id)
        @cart = current_issue_cart

        session[:cart_order_type] = "SalesOrder"
        session[:cart_order_id] = @sales_order.id

        format.html { render action: "edit", notice: "Sales order can not update." }
        format.json { render json: @sales_order.errors, status: :unprocessable_entity }
      end
    end
  end

  # GET /sales_orders/1/confirm
  def confirm
  end

  # GET /sales_orders/1/invoice
  def invoice
    respond_to do |format|
      format.html
      format.pdf do
        render pdf: "file_name",
               layout: "/layouts/pdf.html.erb"
      end
      format.json { render json: @sales_order }
    end
  end

  # GET /sales_orders/1/packing_list
  def packing_list
    respond_to do |format|
      format.html
      format.pdf do
        render pdf: "file_name",
               layout: "/layouts/pdf.html.erb"
      end
      format.json { render json: @sales_order }
    end
  end

  # DELETE /sales_orders/1
  def destroy
    @sales_order.destroy

    respond_to do |format|
      format.html { redirect_to sales_orders_url }
      format.json { head :no_content }
    end
  end

  private

  def set_sales_order
    @sales_order = SalesOrder.find(params[:id])
  end

  def sales_order_params
    params.require(:sales_order).permit(:bill_address, :bill_contact, :bill_telephone, :customer_id,
                                        :payment_term, :serial_number, :ship_address, :ship_contact,
                                        :ship_telephone, :delivery_date, :delivery_status, :delivery_plan,
                                        :exchange_rate, :remark, :created_at,
                                        "delivery_date(1i)", "delivery_date(2i)", "delivery_date(3i)")
  end
end
