class LineItemsController < ApplicationController
  skip_before_filter :authorize, :only => :create

  # GET /line_items
  # GET /line_items.json
  def index
    @line_items = LineItem.all.order(id: :asc)

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

  # POST /line_items?item_id=3  ;po_cart: add line_item 
  # POST /line_items?line_id=3  ;so_cart: add issue_line_item
  # POST /line_items?line_id=3?reverse_order=true; po_cart add line_item
  def create
    if(params[:line_id]) # issue, unissue, reverse po according refer line_id
      if params[:reverse_order] # reverse po
        @cart = current_cart
        so_line = LineItem.find(params[:line_id])
  
        logger.debug "=====##reverse##cart.add_po_line_item:item, quantity== 
                      #{so_line.full_part_number}, #{params[:quantity]}"
        @line_item = @cart.add_po_line_item(so_line.price_id, 
          so_line.full_part_number, 0-params[:quantity].to_i, so_line.fixed_price, so_line.id)        
      else # cart.add_so_line_item & issue, unissue po
        @cart = current_issue_cart
        po_line = LineItem.find(params[:line_id])
        logger.debug "=====cart.add_so_line_item, quantity==  #{params[:quantity]}"
        @line_item = @cart.add_so_line_item(po_line, params[:quantity].to_i)
      end 
    else  # cart.add_po_line_item
      @cart = current_cart
      item = Item.find(params[:item_id])
      item_suffix = '' if (params[:suffix] == '' or params[:suffix].nil?)
      full_part_number = item.partNo + item_suffix
      fixed_price = Price.find(params[:price_id]).price

      logger.debug "=====cart.add_po_line_item:item, quantity== #{full_part_number}, #{params[:quantity]}"
      @line_item = @cart.add_po_line_item(params[:price_id], 
                      full_part_number, params[:quantity].to_i, fixed_price, nil)
    end

    respond_to do |format|
      if @line_item.save
        format.html { redirect_to @line_item, notice: 'Line item was successfully created.' }
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
        format.js {}
        format.json { head :no_content }
      else
        format.html { render action: "edit" }
        format.js {}
        format.json { render json: @line_item.errors, status: :unprocessable_entity }
      end
    end
  end

  # DELETE /line_items/1
  # DELETE /line_items/1.json
  def destroy
    @line_item = LineItem.find(params[:id])
    @line_item.destroy

    if session[:cart_order_type] == "SalesOrder"
      @cart = current_issue_cart
    else
      @cart = current_cart
    end

    respond_to do |format|
      format.html { redirect_to line_items_url }
      format.js {}
      format.json { head :no_content }
    end
  end
end
