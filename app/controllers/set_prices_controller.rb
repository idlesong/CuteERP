class SetPricesController < ApplicationController
  # GET /set_prices
  # GET /set_prices.json
  def index
    @set_prices = SetPrice.all

    @latest_release_set_price = SetPrice.order(released_at: :asc).last
    @latest_set_prices = SetPrice.order("item_id ASC").order("order_quantity::integer ASC").where("released_at" => @latest_release_set_price.released_at )

    @uniq_items = SetPrice.where("released_at" => @latest_release_set_price.released_at ).select(:item_id).uniq
   
    step_quantities = ["1000", "2500", "5000", "10000", "50000"]

    @price_by_items = Array.new
    @uniq_items.each do |item|  
      step_quantities.each do |quantity, q|
        if  @latest_set_prices.where(item_id: item.item_id, order_quantity: quantity).first.nil? 
          @price_by_items << 0
        else
          @price_by_items << @latest_set_prices.where(item_id: item.item_id, order_quantity: quantity).first.price
        end  
      end
    end   

    respond_to do |format|
      format.html # index.html.erb
      format.json { render json: @set_prices }
    end
  end

  # GET /set_prices/1
  # GET /set_prices/1.json
  def show
    @set_price = SetPrice.find(params[:id])

    respond_to do |format|
      format.html # show.html.erb
      format.json { render json: @set_price }
    end
  end

#   # GET /set_prices/1/apply
#   def apply
#     @set_price = SetPrice.find(params[:id])

#     respond_to do |format|
#       format.html # show.html.erb
#       format.pdf  do
#         render pdf: "file_name",
#         layout:      "/layouts/pdf.html.erb"
#       end
#     end
#   end

  # GET /set_prices/new
  # GET /set_prices/new.json
  def new
    @set_price = SetPrice.new
    @customers = Customer.order("credit DESC").where("credit > ?", 0)

    respond_to do |format|
      format.html # new.html.erb
      format.json { render json: @set_price }
    end
  end

  # GET /set_prices/1/edit
  def edit
    @set_price = SetPrice.find(params[:id])
    # @customers = Customer.order("credit DESC").where("credit > ?", 0)    
  end

  # POST /set_prices
  # POST /set_prices.json
  def create
    @set_price = SetPrice.new(params[:set_price])

    respond_to do |format|
      if @set_price.save
        format.html { redirect_to @set_price, notice: 'SetPrice was successfully created.' }
        format.json { render json: @set_price, status: :created, location: @set_price }
      else
        format.html { render action: "new" }
        format.json { render json: @set_price.errors, status: :unprocessable_entity }
      end
    end
  end

  # PUT /set_prices/1
  # PUT /set_prices/1.json
  def update
    @set_price = SetPrice.find(params[:id])

    respond_to do |format|
      if @set_price.update_attributes(params[:set_price])
        format.html { redirect_to @set_price, notice: 'SetPrice was successfully updated.' }
        format.json { head :no_content }
      else
        format.html { render action: "edit" }
        format.json { render json: @set_price.errors, status: :unprocessable_entity }
      end
    end
  end

  # DELETE /set_prices/1
  # DELETE /set_prices/1.json
  def destroy
    @set_price = SetPrice.find(params[:id])
    @set_price.destroy

    respond_to do |format|
      format.html { redirect_to set_prices_url }
      format.json { head :no_content }
    end
  end
end
