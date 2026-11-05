class PricesController < ApplicationController
  before_action :set_price, only: [:show, :edit, :update, :destroy, :apply]

  # GET /prices
  def index
    if params[:status] == "effective"
      @prices = Price.where(status: %w[active approved]).order("created_at asc")
    elsif params[:status] == "requested"
      @prices = Price.where(status: [nil, "requested"]).order("created_at asc")
    else
      @prices = Price.order("created_at asc").all
    end

    @prices = Price.where(is_prr: 1).order("created_at asc") if params[:is_prr]

    respond_to do |format|
      format.html
      format.json { render json: @prices }

      format.xlsx { send_data Price.export_xlsx(@prices), filename: "价格_#{Date.current.strftime("%Y%m%d")}.xlsx" }
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

    # 切换客户会话
    if params[:customer_id] && (params[:customer_id] != current_customer.id.to_s)
      session[:customer_id] = params[:customer_id]
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
        format.html { redirect_to(params[:inline] ? prices_url(index_scope) : @price, notice: "Price was successfully created.") }
        format.json { render json: @price, status: :created, location: @price }
      else
        if params[:inline]
          redirect_to prices_url(index_scope), alert: "价格创建失败（#{@price.errors.full_messages.to_sentence}；也可能与现有报价重复）"
        else
          format.html { redirect_to proc { new_price_url(@price) }, notice: "Price was not valid: maybe duplicated." }
          format.json { render json: @price.errors, status: :unprocessable_entity }
        end
      end
    end
  end

  # PATCH/PUT /prices/1
  def update
    # 纯状态变更（批准）：不带 price 字段，直接更新状态
    if params[:status].present?
      if @price.update(status: params[:status])
        redirect_to prices_url(index_scope), notice: "价格已批准（#{@price.price_number}）"
      else
        redirect_to prices_url(index_scope), alert: @price.errors.full_messages.to_sentence
      end
      return
    end

    respond_to do |format|
      if @price.update(price_params)
        if params[:inline_edit]
          format.html { redirect_to prices_url(index_scope), notice: "价格已更新（#{@price.price_number}）" }
          format.json { head :no_content }
        elsif params[:status]
          format.html { redirect_to prices_url }
        else
          format.html { redirect_to @price, notice: "Price was successfully updated." }
          format.json { head :no_content }
        end
      else
        format.html do
          if params[:inline]
            redirect_to prices_url, alert: "价格未保存：#{@price.errors.full_messages.to_sentence}"
          else
            redirect_to proc { edit_price_url(@price) }, notice: "Price was not valid, maybe duplicated"
          end
        end
        format.json { render json: @price.errors, status: :unprocessable_entity }
      end
    end
  end

  # GET /prices/options?customer_id=&part_number= —— 下单快速创建的价格下拉（生效/已批准价格）
  def options
    scope = Price.where(status: %w[active approved])
                 .where("effective_from IS NULL OR effective_from <= ?", Date.current)
                 .where("expired_at IS NULL OR expired_at >= ?", Date.current)
    scope = scope.where(customer_id: params[:customer_id]) if params[:customer_id].present?
    scope = scope.where(part_number: params[:part_number]) if params[:part_number].present?

    if params[:parts_only]
      render json: scope.distinct.order(:part_number).pluck(:part_number)
      return
    end

    if params[:info]
      customer = Customer.find_by(id: params[:customer_id])
      tier = nil
      if customer && params[:part_number].present?
        tier = PriceListEntry.tier_price(params[:part_number], customer.sales_type, params[:condition].to_i)
      end
      render json: { sales_type: customer&.sales_type, tier: tier }
      return
    end

    data = scope.order(:price).map do |p|
      unit = p.currency == "USD" ? "$" : "\u00a5"
      components = [p.base_price, p.v1_price, p.v2_price].compact
      label = "#{unit}#{p.price}"
      label += " (=#{components.join('+')})" if components.size > 1
      label += " /#{p.condition}pcs" if p.condition.present?
      { id: p.id, label: label }
    end
    render json: data
  end

  # POST /prices/import —— 价格列表页导入入口（与导入中心同口径：批次记录 + 统一报告）
  def import
    import = Price.import(params[:file], imported_by: current_user)
    redirect_to prices_url, notice: import_report(import)
  rescue StandardError => e
    redirect_to prices_url, alert: "报价导入失败：#{e.message}"
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

  # 列表页快捷编辑/快速创建后回到原筛选视图：
  # 服务端 scope 参数经表单隐藏字段 list_* 带回（客户端筛选/页码由 DataTables stateSave 恢复）
  def index_scope
    { status: params[:list_status].presence, is_prr: params[:list_is_prr].presence }.compact
  end

  def price_params
    p = params.require(:price).permit(:boss_suggestion, :condition, :customer_id, :department_suggestion,
                                      :finance_suggestion, :payment_terms, :price, :sales_suggestion,
                                      :status, :remark, :created_at, :base_price, :v1_price, :v2_price,
                                      :price_number, :part_number, :customer_name, :is_prr,
                                      :effective_from, :expired_at)
    # status can also be updated via a top-level params[:status] (approval workflow)
    p[:status] = params[:status] if params[:status].present? && p[:status].blank?
    p
  end
end
