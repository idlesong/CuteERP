class LineItemsController < ApplicationController
  skip_before_filter :authorize, :only => :create

  # GET /line_items
  # GET /line_items.json
  def index
    @line_items = LineItem.all

    respond_to do |format|
      format.html # index.html.erb
      format.json { render json: @line_items }
    end
  end

  # GET /line_items/1
  # GET /line_items/1.json
  def show
    @line_item = LineItem.find(params[:id])

    respond_to do |format|
      format.html # show.html.erb
      format.json { render json: @line_item }
    end
  end

  # GET /line_items/new
  # GET /line_items/new.json
  def new
    @line_item = LineItem.new

    respond_to do |format|
      format.html # new.html.erb
      format.json { render json: @line_item }
    end
  end

  # GET /line_items/1/edit
  def edit
    @line_item = LineItem.find(params[:id])
  end

  # POST /line_items
  # POST /line_items.json
  def create

    if(params[:line_id])
      @cart = current_issue_cart
      line = LineItem.find(params[:line_id])
      # logger.debug "=====quantity== #{params[:quantity]}"

      if(params[:quantity].to_i <= line.quantity - line.quantity_issued)
        @line_item = @cart.issue_line_item(line, params[:quantity].to_i)
      end
    else
      @cart = current_cart
      item = Item.find(params[:item_id])
      # logger.debug "=====quantity== #{params[:quantity]}"
      price = current_customer.get_special_price(item)
      @line_item = @cart.add_item(item.id, params[:quantity].to_i, price)
    end

    respond_to do |format|
      if @line_item.save
        #format.html { redirect_to @line_item, notice: 'Line item was successfully created.' }
        format.html { redirect_to (inventory_url)}
        format.js {}
        format.json { render json: @line_item, status: :created, location: @line_item }
      else
        format.html { render action: "new" }
        format.js {}
        format.json { render json: @line_item.errors, status: :unprocessable_entity }
      end
    end
  end

  # PUT /line_items/1
  # PUT /line_items/1.json
  def update
    @line_item = LineItem.find(params[:id])

    respond_to do |format|
      if @line_item.update_attributes(params[:line_item])
        format.html { redirect_to @line_item, notice: 'Line item was successfully updated.' }
        format.json { head :no_content }
      else
        format.html { render action: "edit" }
        format.json { render json: @line_item.errors, status: :unprocessable_entity }
      end
    end
  end

  # DELETE /line_items/1
  # DELETE /line_items/1.json
  def destroy
    @line_item = LineItem.find(params[:id])
    @line_item.destroy

    respond_to do |format|
      format.html { redirect_to line_items_url }
      format.json { head :no_content }
    end
  end
end
