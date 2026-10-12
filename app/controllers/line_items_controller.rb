class LineItemsController < ApplicationController
  skip_before_action :authorize, only: :create

  before_action :set_line_item, only: [:show, :edit, :update, :destroy]

  # GET /line_items
  def index
    @line_items = LineItem.all.order(id: :asc)

    respond_to do |format|
      format.html
      format.json { render json: @line_items }
    end
  end

  # GET /line_items/1
  def show
    respond_to do |format|
      format.html
      format.json { render json: @line_item }
    end
  end

  # GET /line_items/new
  def new
    @line_item = LineItem.new

    respond_to do |format|
      format.html
      format.json { render json: @line_item }
    end
  end

  # GET /line_items/1/edit
  def edit
  end

  # POST /line_items?item_id=3  ;po_cart: add line_item
  # POST /line_items?line_id=3  ;so_cart: add issue_line_item
  # POST /line_items?line_id=3&reverse_order=true ; po_cart add line_item
  def create
    if params[:line_id] # issue, unissue, reverse po according refer line_id
      if params[:reverse_order] # reverse po
        @cart = current_cart
        so_line = LineItem.find(params[:line_id])

        logger.debug "=====##reverse##cart.add_po_line_item:item, quantity==
                      #{so_line.full_part_number}, #{params[:quantity]}"
        @line_item = @cart.add_po_line_item(so_line.price_id,
                                            so_line.full_part_number, 0 - params[:quantity].to_i, so_line.fixed_price, so_line.id)
      else # cart.add_so_line_item & issue, unissue po
        @cart = current_issue_cart
        po_line = LineItem.find(params[:line_id])
        logger.debug "=====cart.add_so_line_item, quantity==  #{params[:quantity]}"
        @line_item = @cart.add_so_line_item(po_line, params[:quantity].to_i)
      end
    else # cart.add_po_line_item
      @cart = current_cart
      item = Item.find(params[:item_id])
      item_suffix = "" if params[:suffix].blank?
      full_part_number = item.partNo + item_suffix
      fixed_price = Price.find(params[:price_id]).price

      logger.debug "=====cart.add_po_line_item:item, quantity== #{full_part_number}, #{params[:quantity]}"
      @line_item = @cart.add_po_line_item(params[:price_id],
                                          full_part_number, params[:quantity].to_i, fixed_price, nil)
    end

    respond_to do |format|
      if @line_item.save
        format.html { redirect_to @line_item, notice: "Line item was successfully created." }
        format.turbo_stream
        format.json { render json: @line_item, status: :created, location: @line_item }
      else
        format.html { render action: "new" }
        format.turbo_stream { render json: @line_item.errors, status: :unprocessable_entity }
        format.json { render json: @line_item.errors, status: :unprocessable_entity }
      end
    end
  end

  # PATCH/PUT /line_items/1
  def update
    respond_to do |format|
      if params[:uniform_number] # produce with uniform_number
        @line_item.update_attribute(:full_name, params[:full_name])
        @line_item.update_attribute(:remark, params[:remark])
        format.html { redirect_to @line_item, notice: "Line item was successfully updated." }
        format.js { head :no_content }
        format.json { head :no_content }
      elsif @line_item.update(line_item_params)
        format.html { redirect_to @line_item, notice: "Line item was successfully updated." }
        format.js { head :no_content }
        format.json { head :no_content }
      else
        format.html { render action: "edit" }
        format.js { render json: @line_item.errors, status: :unprocessable_entity }
        format.json { render json: @line_item.errors, status: :unprocessable_entity }
      end
    end
  end

  # DELETE /line_items/1
  def destroy
    @line_item.destroy

    if session[:cart_order_type] == "SalesOrder"
      @cart = current_issue_cart
    else
      @cart = current_cart
    end

    respond_to do |format|
      format.html { redirect_to line_items_url }
      format.js { head :no_content }
      format.json { head :no_content }
    end
  end

  private

  def set_line_item
    @line_item = LineItem.find(params[:id])
  end

  def line_item_params
    params.require(:line_item).permit(:cart_id, :item_id, :quantity, :order_id, :price_id, :remark,
                                      :quantity_issued, :refer_line_id, :fixed_price, :full_part_number,
                                      :full_name, :line_number)
  end
end
