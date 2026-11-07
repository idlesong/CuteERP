class CustomersController < ApplicationController
  before_action :set_customer, only: [:show, :edit, :update, :destroy]

  # GET /customers
  def index
    @customers = Customer.all

    respond_to do |format|
      format.html
      format.json { render json: CustomersDatatable.new(view_context) }

      format.xlsx { send_data Customer.export_xlsx, filename: "客户_#{Date.current.strftime("%Y%m%d")}.xlsx" }
    end
  end

  # GET /customers/1
  def show
    @contacts = Contact.where("customer_id = ?", @customer.id)

    # 当月对账（订单核对/出货核对/未交订单），月份可切换，默认当月（与月度对账页同口径）
    @statement_month = parse_month(params[:month]) || Date.current.beginning_of_month
    @statement = MonthlyStatement.new(@customer, @statement_month)

    # 已签发待发货：还有未出完生产行的六联单（与工作台同判定）
    orders = @customer.sales_orders.includes(:production_lines).order(created_at: :desc)
    @unshipped_sales_orders = orders.reject do |so|
      so.production_lines.all? { |pl| pl.unshipped_qty <= 0 }
    end

    # 价格列表：默认只显示生效价格；params[:all_prices]=1 显示全部非归档
    @prices = if params[:all_prices]
                @customer.prices.where.not(status: "archived")
              else
                @customer.prices.available
              end

    # add session id to customer id when show a customer
    session[:customer_id] = @customer.id

    respond_to do |format|
      format.html
      format.js
    end
  end

  # GET /customers/new
  def new
    @customer = Customer.new

    @disties = Customer.where.not(sales_type: "OEM")
    respond_to do |format|
      if params[:simplify] == "yes"
        format.html { render "new_simplify" }
        format.js
      else
        format.html
        format.js
      end
    end
  end

  # GET /customers/1/edit
  def edit
    @disties = Customer.where.not(sales_type: "OEM")
    @disties = Customer.none if @disties.nil?
  end

  # POST /customers
  def create
    @customer = Customer.new(customer_params)

    respond_to do |format|
      if @customer.save
        format.html { redirect_to(params[:inline] ? customers_url : @customer, notice: "Customer was successfully created.") }
        format.json { render json: @customer, status: :created, location: @customer }
      else
        if params[:inline]
          redirect_to customers_url, alert: @customer.errors.full_messages.to_sentence
        else
          format.html { render action: "new" }
          format.json { render json: @customer.errors, status: :unprocessable_entity }
        end
      end
    end
  end

  # PATCH/PUT /customers/1
  def update
    respond_to do |format|
      if @customer.update(customer_params)
        notice = "Customer was successfully updated."
        format.html { redirect_to(params[:inline_edit] ? customers_url : @customer, notice: notice) }
        format.json { head :no_content }
      else
        format.html { render action: "edit" }
        format.json { render json: @customer.errors, status: :unprocessable_entity }
      end
    end
  end

  # DELETE /customers/1
  def destroy
    respond_to do |format|
      if @customer.destroy
        format.html { redirect_to customers_url }
        format.json { head :no_content }
      else
        format.html { redirect_to customer_url(@customer), notice: "customer can't be destroyed" }
        format.json { render json: @customer.errors, status: :unprocessable_entity }
      end
    end
  end

  # POST /customers/import
  def import
    import = Customer.import(params[:file], imported_by: current_user)
    redirect_to customers_url, notice: import_report(import)
  rescue StandardError => e
    redirect_to customers_url, alert: "客户导入失败：#{e.message}"
  end

  private

  def set_customer
    @customer = Customer.find(params[:id])
  end

  def parse_month(raw)
    Date.strptime(raw.to_s, "%Y-%m").beginning_of_month
  rescue ArgumentError, TypeError
    nil
  end

  def customer_params
    params.require(:customer).permit(:address, :balance, :contact, :name, :full_name, :since,
                                     :telephone, :payment, :currency, :ship_contact, :ship_address,
                                     :ship_telephone, :credit, :sales_type, :disty_id, :territory,
                                     :name_zh, :invoice_address, :invoice_contact, :invoice_phone)
  end
end
