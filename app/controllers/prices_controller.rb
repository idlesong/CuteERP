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

    # clear cart, when customer switched
    if params[:customer_id] && (params[:customer_id] != current_customer.id.to_s)
      session[:customer_id] = params[:customer_id]
      current_cart.line_items.clear
    end

    @customer = current_customer
    @price.customer = @customer
    @price.currency = @customer.currency

    # 从最新阶梯批次快填（params[:part_number] + params[:qty]）
    if params[:part_number].present? && params[:qty].present?
      @price.part_number = params[:part_number]
      @price.condition = params[:qty]
      tier = PriceListEntry.tier_price(params[:part_number], @customer.sales_type, params[:qty])
      @price.price = tier if tier
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
    @customer = current_customer

    # 从最新阶梯批次快填（params[:part_number] + params[:qty]）
    if params[:part_number].present? && params[:qty].present?
      @price.part_number = params[:part_number]
      @price.condition = params[:qty]
      tier = PriceListEntry.tier_price(params[:part_number], @customer.sales_type, params[:qty])
      @price.price = tier if tier
    end

    session[:current_path_action] = "edit"
  end

  # POST /prices
  def create
    @price = Price.new(price_params)
    @customers = Customer.order("credit DESC").where("credit > ?", 0)

    # 行内快速创建：自动单号 + 客户名带出
    if params[:inline]
      @price.price_number = @price.generate_price_number if @price.price_number.blank?
      @price.customer_name = @price.customer&.name
    end

    respond_to do |format|
      if @price.save
        format.html { redirect_to(params[:inline] ? prices_url : @price, notice: "Price was successfully created.") }
        format.json { render json: @price, status: :created, location: @price }
      else
        if params[:inline]
          redirect_to prices_url, alert: "价格创建失败（#{@price.errors.full_messages.to_sentence}；也可能与现有报价重复）"
        else
          format.html { redirect_to proc { new_price_url(@price) }, notice: "Price was not valid: maybe duplicated." }
          format.json { render json: @price.errors, status: :unprocessable_entity }
        end
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
                                      :finance_suggestion, :payment_terms, :price, :sales_suggestion,
                                      :status, :remark, :created_at, :base_price, :v1_price, :v2_price,
                                      :price_number, :part_number, :customer_name, :is_prr)
    # status can also be updated via a top-level params[:status] (approval workflow)
    p[:status] = params[:status] if params[:status].present? && p[:status].blank?
    p
  end
end
