class PricesController < ApplicationController
  # GET /prices
  # GET /prices.json
  def index
    # @prices = Price.all
    if(params[:status])
      if(params[:status] == "effective")
        effective = ["active", "approved"]
        @prices = Price.where(status: effective).order("created_at asc")
      else
        @prices = Price.where(status: params[:status]).order("created_at asc")
      end
    else
      @prices = Price.order("created_at asc").all
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

    @latest_release_set_price = SetPrice.order(released_at: :asc).last
    @latest_set_prices = SetPrice.order("item_id ASC").where("released_at" => @latest_release_set_price.released_at )

    @step_quantities = @latest_release_set_price.settings(:step_quantities).quantities
    @price_list_prices = @latest_release_set_price.get_price_list(@step_quantities, 'price')
    @price_list_ids = @latest_release_set_price.get_price_list(@step_quantities, 'id')

    # clear cart and destroy associated line_items, when customer switched
    if (params[:customer_id] && (params[:customer_id] != current_customer.id))
      session[:customer_id] = params[:customer_id]
      current_cart.line_items.clear
    end
    
    @customer = current_customer
    @price.customer = @customer

    if (params[:item_id] && params[:price_id] && params[:condition])
      @set_price = SetPrice.find(params[:price_id])
      @price.item_id = @set_price.item_id # Item.find_by(partNo: params[:item_id]).id
      @price.price = @set_price.price
      @price.base_price = @set_price.base_price
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

    @latest_set_prices = SetPrice.order("item_id ASC").where("released_at" => @latest_release_set_price.released_at )

    @step_quantities = @latest_release_set_price.settings(:step_quantities).quantities    
    @price_list_prices = @latest_release_set_price.get_price_list(@step_quantities, "price")
    @price_list_ids = @latest_release_set_price.get_price_list(@step_quantities, 'id')    

    if (params[:set_price_id] && params[:condition])
      @set_price = SetPrice.find(params[:set_price_id])
      @price.item_id = @set_price.item_id
      @price.price = @set_price.price
      @price.condition = params[:condition]
    end

    session[:current_path_action] = 'edit'

  end

  # GET /prices/lookup_set_price
  def lookup_set_price
    if (params[:item_id] && params[:price] && params[:condition])
      @price.item_id = Item.find_by(partNo: params[:item_id]).id
      @price.price = params[:price]
      @price.condition = params[:condition]
    end    
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
        format.html { render action: "new" }
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

      # auto achive old price, when active old price
      # if params[:status] == 'active'
      #   @prices = Price.where(item_id: @price.item_id, condition: @price.condition)
      #   @prices.update_all(status: "achived")   
      # end
    end

    respond_to do |format|
      if @price.update_attributes(params[:price])
        if params[:status]
          format.html { redirect_to prices_url }
        else
        format.html { redirect_to @price, notice: 'Price was successfully updated.' }
        format.json { head :no_content }
        end
      else
        format.html { render action: "edit" }
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
