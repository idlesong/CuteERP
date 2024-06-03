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

    @sales_order.initialize_order_header(@customer)
    @sales_order.exchange_rate = monthly_exchange_rate

    @cart = current_issue_cart
    @cart.line_items.clear
    # session[:cart_order_type] = "SalesOrder"
    # session[:cart_currency] = @sales_order.customer.currency
    # session[:exchange_rate] = @sales_order.exchange_rate

    respond_to do |format|
      format.html # new.html.erb
      format.json { render json: @sales_order }
    end
  end

  # GET /sales_orders/1/edit
  def edit
    @sales_order = SalesOrder.find(params[:id])
    @orders = Order.where(customer_id: @sales_order.customer_id)

    @cart = current_issue_cart

    # @cart.line_items.clear
    @cart.copy_line_items_from_sales_order(@sales_order)
    # @cart.line_items.clear
    # @sales_order.line_items.each do |line|
    #   new_line = line.dup
    #   new_line.line = nil
    #   new_line.line_number = 'cart' + new_line.line_number # must uniq
    #   @cart.line_items << new_line
    # end    

    session[:cart_order_type] = "SalesOrder"
    session[:cart_currency] = @sales_order.customer.currency
    session[:exchange_rate] = @sales_order.exchange_rate

    respond_to do |format|
      format.html
      format.json
    end    

  end

  # POST /sales_orders
  # POST /sales_orders.json
  def create
    @sales_order = SalesOrder.new(params[:sales_order])
    @sales_order.add_line_items_from_issue_cart(current_issue_cart)

    # @sales_order.customer_id = session[:customer_id]
    respond_to do |format|
      if @sales_order.save

        @sales_order.issue_refer_line_items

        Cart.destroy(session[:issue_cart_id])
        session[:issue_cart_id] = nil

        format.html { redirect_to @sales_order, notice: 'Sales order was successfully created.' }
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

  # PUT /sales_orders/1
  # PUT /sales_orders/1.json
  def update
    @sales_order = SalesOrder.find(params[:id])

    # update delivery_status only(includes reschedule devlivery_plan) 
    if (params[:sales_order][:delivery_status])
        logger.debug "==####==update delivery status= #{params[:sales_order][:delivery_status]}"
    else
      # skip when cart is empty.
      if current_issue_cart.line_items.exists? 
        logger.debug "==####==current_issue_cart_has_line_items="
        @sales_order.issue_unissue_po_line_items_when_so_and_cart_diffs(current_issue_cart)  

        @sales_order.line_items.clear
        @sales_order.add_line_items_from_issue_cart(current_issue_cart)

        @sales_order.save
        # Cart.destroy(session[:issue_cart_id])
        # session[:issue_cart_id] = nil     
      end

      # confirm_and_dispatch_order if develivery_date exist
      if (params[:sales_order][:"delivery_date(1i)"])
        delivery_plan = Time.new(params[:sales_order][:"delivery_date(1i)"],
                                params[:sales_order][:"delivery_date(2i)"],
                                params[:sales_order][:"delivery_date(3i)"])
        logger.debug "==####==confirm and dispatch: delivery_plan= #{delivery_plan}"

        # @sales_order.delivery_date_overwrite_delivery_plan(delivery_plan)
        @sales_order.update_attribute(:delivery_plan, delivery_plan + 8.hour)
      end
      @sales_order.save      
      
    end  

    respond_to do |format|
      if @sales_order.update_attributes(params[:sales_order])
        format.html { redirect_to @sales_order, notice: 'Sales order was successfully updated.' }
        format.json { head :no_content }        
      else
        @orders = Order.where(customer_id: @sales_order.customer.id)
        @cart = current_issue_cart

        session[:cart_order_type] = "SalesOrder"
        session[:cart_order_id] = @sales_order.id

        format.html { render action: "edit", notice: 'Sales order can not update.' }
        format.json { render json: @sales_order.errors, status: :unprocessable_entity }
      end
    end
  end

  # GET /sales_orders/1/confirm
  def confirm
    @sales_order = SalesOrder.find(params[:id])
  end

  # GET /sales_orders/1/invoice
  def invoice
    @sales_order = SalesOrder.find(params[:id])

    respond_to do |format|
      format.html # show.html.erb
      format.pdf do
        render pdf: "file_name",
        layout:      "/layouts/pdf.html.erb"
      end
      format.json { render json: @sales_order }
    end
  end

  # GET /sales_orders/1/packing_list
  def packing_list
    @sales_order = SalesOrder.find(params[:id])

    respond_to do |format|
      format.html # show.html.erb
      format.pdf do
        render pdf: "file_name",
        layout:      "/layouts/pdf.html.erb"
      end
      format.json { render json: @sales_order }
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
