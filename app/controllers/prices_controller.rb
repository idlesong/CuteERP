class PricesController < ApplicationController
  # GET /prices
  # GET /prices.json
  def index
    # @prices = Price.all
    if(params[:status])
      if(params[:status] == "active")
        @prices = Price.where(status: "active").order("created_at asc")        
      elsif(params[:status] == "active_approved")
        active_approved = ["active", "approved"]
        @prices = Price.where(status: active_approved).order("created_at asc")
      else
        effective = ["active", "approved", "requested"]
        @prices = Price.where(status: effective).order("created_at asc")        
      end
    else
      @prices = Price.order("created_at asc").all
    end

    if(params[:is_prr])
      @prices = Price.where(is_prr: 1).order("created_at asc")       
    end

    respond_to do |format|
      format.html # index.html.erb
      format.json { render json: @prices }

      format.csv { send_data @prices.export_to_csv }
      format.xls { send_data @prices.export_to_csv(col_sep: "\t") }      
    end
  end

  # GET /prices/1
  # GET /prices/1.json
  def show
    @price = Price.find(params[:id])

    @customer = current_customer

    respond_to do |format|
      format.html # show.html.erb
      format.json { render json: @price }
    end
  end

  # GET /prices/1/apply
  def apply
    @price = Price.find(params[:id])
    file_name = @price.price_number + @price.customer_name + @price.part_number

    respond_to do |format|
      format.html # show.html.erb
      format.pdf  do
        render pdf: file_name,
        layout:      "/layouts/pdf.html.erb"
      end
    end
  end

  # GET /prices/new
  # GET /prices/new.json
  def new
    @price = Price.new
    @price.price_number = @price.generate_price_number
    @customers = Customer.order("credit DESC").where("credit > ?", 0)

    @latest_released_set_price = SetPrice.order(released_at: :asc).last  
    if @latest_released_set_price 
      @latest_set_prices_list = SetPrice.where("released_at" => @latest_released_set_price.released_at)
    end  
    
    # clear cart and destroy associated line_items, when customer switched
    if (params[:customer_id] && (params[:customer_id] != current_customer.id))
      session[:customer_id] = params[:customer_id]
      current_cart.line_items.clear
    end
    
    @customer = current_customer
    @price.customer = @customer

    # get set_price by quantity(params[:condition])
    @step_quantities = current_user.settings(:step_values).quantities
    @step_names = current_user.settings(:step_names).names

    if (params[:set_price_id] && params[:condition])
      @set_price = SetPrice.find(params[:set_price_id])
      @price.item_id = @set_price.item_id
      step_index = @step_quantities.index(params[:condition]).to_i
      step_index += 8 if @customer.sales_type == "ODM"
      step_name = @step_names[step_index]

      @price.price = @set_price[step_name]
      logger.debug "==####@@@@==set_price step_name, value: #{step_name}, #{@set_price[step_name]}"
      @price.base_price = @set_price[step_name] - @set_price.extra_price
      @price.extra_price = @set_price.extra_price     
      @price.condition = params[:condition]
    end

    session[:current_path_action] = 'new'    

    respond_to do |format|
      format.html # new.html.erb
      format.json { render json: @price }
    end
  end

  # GET /prices/1/edit
  def edit
    @price = Price.find(params[:id])
    @customers = Customer.order("credit DESC").where("credit > ?", 0)    
    @latest_release_set_price = SetPrice.order(released_at: :asc).last

    @customer = current_customer

    @latest_released_set_price = SetPrice.order(released_at: :asc).last
    
    if @latest_released_set_price 
      @latest_set_prices_list = SetPrice.where("released_at" => @latest_released_set_price.released_at)
    end  

    # get set_price by quantity(params[:condition])
    @step_quantities = current_user.settings(:step_values).quantities
    @step_names = current_user.settings(:step_names).names  

    if (params[:set_price_id] && params[:condition])
      @set_price = SetPrice.find(params[:set_price_id])
      @price.item_id = @set_price.item_id
      step_index = @step_quantities.index(params[:condition]).to_i
      step_index += 8 if @customer.sales_type == "ODM"
      step_name = @step_names[step_index]      
      @price.price = @set_price[step_name]
      logger.debug "==####@@@@==set_price step_name, value: #{step_name}, #{@set_price[step_name]}"
      @price.base_price = @set_price[step_name] - @set_price.extra_price
      @price.extra_price = @set_price.extra_price     
      @price.condition = params[:condition]
    end

    session[:current_path_action] = 'edit'

  end

  # POST /prices
  # POST /prices.json
  def create
    @price = Price.new(params[:price])
    @customers = Customer.order("credit DESC").where("credit > ?", 0)

    respond_to do |format|
      if @price.save
        format.html { redirect_to @price, notice: 'Price was successfully created.' }
        format.json { render json: @price, status: :created, location: @price }
      else
        # format.html { render action: "new" }
        format.html { redirect_to proc { new_price_url(@price) }, notice: 'Price was not valid: maybe duplicated.' }
        format.json { render json: @price.errors, status: :unprocessable_entity }
      end
    end
  end

  # PUT /prices/1
  # PUT /prices/1.json
  def update
    @price = Price.find(params[:id])

    if params[:status]
      @price.status = params[:status] 
    end

    # @latest_released_set_price = SetPrice.order(released_at: :asc).last
    # @step_quantities = @latest_release_set_price.settings(:step_quantities).quantities 
    # @step_quantities = [1, 1000, 2500, 5000, 10000, 20000, 50000, 100000]
    @step_quantities = current_user.settings(:step_values).quantities    

    respond_to do |format|
      if @price.update_attributes(params[:price])
        if params[:status]
          format.html { redirect_to prices_url }
        else
        format.html { redirect_to @price, notice: 'Price was successfully updated.' }
        format.json { head :no_content }
        end
      else
        format.html { redirect_to proc { edit_price_url(@price) }, notice: 'Price was not valid, maybe duplicated' }
        # format.html { render action: "edit" }
        format.json { render json: @price.errors, status: :unprocessable_entity }
      end
    end
  end

  def import
    Price.import(params[:file])
    redirect_to prices_url, notice: "Prices imported."
  end  

  # DELETE /prices/1
  # DELETE /prices/1.json
  def destroy
    @price = Price.find(params[:id])
    @price.destroy

    respond_to do |format|
      format.html { redirect_to prices_url }
      format.json { head :no_content }
    end
  end      
end
