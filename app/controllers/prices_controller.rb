class PricesController < ApplicationController
  before_action :set_price, only: [:show, :edit, :update, :destroy, :apply]

  # GET /prices
  def index
    if params[:status]
      if params[:status] == "active"
        @prices = Price.where(status: "active").order("created_at asc")
      elsif params[:status] == "active_approved"
        active_approved = ["active", "approved"]
        @prices = Price.where(status: active_approved).order("created_at asc")
      else
        effective = ["active", "approved", "requested"]
        @prices = Price.where(status: effective).order("created_at asc")
      end
    else
      @prices = Price.order("created_at asc").all
    end

    @prices = Price.where(is_prr: 1).order("created_at asc") if params[:is_prr]

    respond_to do |format|
      format.html
      format.json { render json: @prices }

      format.csv { send_data @prices.export_to_csv }
      format.xls { send_data @prices.export_to_csv(col_sep: "\t") }
    end
  end

  # GET /prices/1
  def show
    @customer = current_customer

    respond_to do |format|
      format.html
      format.json { render json: @price }
    end
  end

  # GET /prices/1/apply
  def apply
    file_name = [@price.price_number, @price.customer_name, @price.part_number].compact.join

    respond_to do |format|
      format.html
      format.pdf do
        render pdf: file_name,
               layout: "pdf"
      end
    end
  end

  # GET /prices/new
  def new
    @price = Price.new
    @price.price_number = @price.generate_price_number
    @customers = Customer.order("credit DESC").where("credit > ?", 0)

    @latest_released_set_price = SetPrice.order(released_at: :asc).last
    if @latest_released_set_price
      @latest_set_prices_list = SetPrice.where("released_at" => @latest_released_set_price.released_at)
    end

    # clear cart and destroy associated line_items, when customer switched
    if params[:customer_id] && (params[:customer_id] != current_customer.id.to_s)
      session[:customer_id] = params[:customer_id]
      current_cart.line_items.clear
    end

    @customer = current_customer
    @price.customer = @customer

    # get set_price by quantity(params[:condition])
    @step_quantities = current_user.settings(:step_values).quantities
    @step_names = current_user.settings(:step_names).names

    if params[:set_price_id] && params[:condition]
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

    session[:current_path_action] = "new"

    respond_to do |format|
      format.html
      format.json { render json: @price }
    end
  end

  # GET /prices/1/edit
  def edit
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

    if params[:set_price_id] && params[:condition]
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

    session[:current_path_action] = "edit"
  end

  # POST /prices
  def create
    @price = Price.new(price_params)
    @customers = Customer.order("credit DESC").where("credit > ?", 0)

    # 行内快速创建：自动单号、通用型号关联（缺失时惰性创建）、客户名带出
    if params[:inline]
      @price.price_number = @price.generate_price_number if @price.price_number.blank?
      item = Item.find_by_any_part_no(@price.part_number.to_s)
      unless item
        base, sfx = Item.split_part_no(@price.part_number)
        item = Item.create!(generic_part_no: base, suffix: sfx, name: base)
      end
      @price.item_id = item.id
      @price.customer_name = @price.customer&.name
    end

    respond_to do |format|
      if @price.save
        format.html { redirect_to(params[:inline] ? prices_url : @price, notice: "Price was successfully created.") }
        format.json { render json: @price, status: :created, location: @price }
      else
        format.html { redirect_to proc { new_price_url(@price) }, notice: "Price was not valid: maybe duplicated." }
        format.json { render json: @price.errors, status: :unprocessable_entity }
      end
    end
  end

  # PATCH/PUT /prices/1
  def update
    @step_quantities = current_user.settings(:step_values).quantities

    respond_to do |format|
      if @price.update(price_params)
        if params[:status]
          format.html { redirect_to prices_url }
        else
          format.html { redirect_to @price, notice: "Price was successfully updated." }
          format.json { head :no_content }
        end
      else
        format.html { redirect_to proc { edit_price_url(@price) }, notice: "Price was not valid, maybe duplicated" }
        format.json { render json: @price.errors, status: :unprocessable_entity }
      end
    end
  end

  # POST /prices/import
  def import
    Price.import(params[:file])
    redirect_to prices_url, notice: "Prices imported."
  end

  # DELETE /prices/1
  def destroy
    @price.destroy

    respond_to do |format|
      format.html { redirect_to prices_url }
      format.json { head :no_content }
    end
  end

  private

  def set_price
    @price = Price.find(params[:id])
  end

  def price_params
    p = params.require(:price).permit(:boss_suggestion, :condition, :customer_id, :department_suggestion,
                                      :finance_suggestion, :item_id, :payment_terms, :price, :sales_suggestion,
                                      :status, :remark, :created_at, :base_price, :extra_price,
                                      :price_number, :part_number, :customer_name, :is_prr)
    # status can also be updated via a top-level params[:status] (approval workflow)
    p[:status] = params[:status] if params[:status].present? && p[:status].blank?
    p
  end
end
