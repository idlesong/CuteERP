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

  # POST /line_items?line_id=3 —— 签发流：PO 行(OrderLine)加入签发暂存（P4 由分配台账替代）
  def create
    if params[:line_id]
      @cart = current_issue_cart
      po_line = OrderLine.find(params[:line_id])
      logger.debug "=====cart.add_so_line_item, quantity==  #{params[:quantity]}"
      @line_item = @cart.add_so_line_item(po_line, params[:quantity].to_i)
    else
      redirect_to orders_url, alert: "无效的加行请求" and return
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

    @cart = current_issue_cart

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
