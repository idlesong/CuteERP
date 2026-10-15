# 生产订单（六联单）：
# - 签发 = 从客户订单行池（DemandQuery）多选拆量 → production_lines + production_allocations（D2）
# - 生产编排 = 转产选正式型号（同 generic 组选后缀，组内没有可就地新建）
# - 发货 = 出库单 shipments（可多次，末次派生发货时间）
class SalesOrdersController < ApplicationController
  before_action :set_sales_order, only: [:show, :edit, :update, :destroy,
                                         :production, :edit_production, :update_production,
                                         :confirm, :create_shipment, :invoice, :packing_list]

  # GET /sales_orders
  def index
    @sales_orders = SalesOrder.includes(:customer, :production_lines).order(created_at: :desc)

    respond_to do |format|
      format.html
      format.json { render json: @sales_orders }
    end
  end

  def production
  end

  # GET /sales_orders/1/edit_production —— 生产编排（选正式型号）
  def edit_production
  end

  # PATCH /sales_orders/1/update_production
  def update_production
    lines_params.to_h.each do |id, attrs|
      line = @sales_order.production_lines.find(id)
      line.update!(item_id: attrs[:item_id].presence, quantity: attrs[:quantity],
                   version: attrs[:version].presence, full_name: attrs[:full_name].presence,
                   remark: attrs[:remark].presence)
    end
    redirect_to production_sales_order_path(@sales_order), notice: "生产编排已保存"
  rescue ActiveRecord::RecordInvalid => e
    redirect_to edit_production_sales_order_path(@sales_order), alert: e.message
  end

  # GET /sales_orders/new?customer_id= —— 签发：客户维度未分配 PO 行池
  def new
    @sales_order = SalesOrder.new
    @customer = Customer.find(params[:customer_id])
    @sales_order.initialize_order_header(@customer)
    @sales_order.snapshot_exchange_rate!
    @pool = DemandQuery.allocatable_lines(customer_id: @customer.id)
  end

  # POST /sales_orders  lines[<order_line_id>][item_id/quantity/version/full_name/remark]
  def create
    customer = Customer.find(sales_order_params[:customer_id])
    @sales_order = SalesOrder.new(customer: customer)
    @sales_order.assign_attributes(sales_order_params.except(:customer_id))
    @sales_order.initialize_order_header(customer)
    @sales_order.snapshot_exchange_rate!

    entries = lines_params.to_h.select { |_, attrs| attrs[:quantity].to_i.positive? }

    SalesOrder.transaction do
      entries.each do |ol_id, attrs|
        order_line = OrderLine.find(ol_id)
        item = resolve_item(order_line, attrs[:suffix])
        line = @sales_order.production_lines.build(
          item: item, quantity: attrs[:quantity].to_i,
          version: attrs[:version].presence,
          full_name: attrs[:full_name].presence || item.name,
          remark: attrs[:remark].presence
        )
        line.production_allocations.build(order_line: order_line, quantity: attrs[:quantity].to_i)
      end
      @sales_order.save!
    end
    redirect_to @sales_order, notice: "六联单 #{@sales_order.serial_number} 已创建"
  rescue ActiveRecord::RecordInvalid, ActiveRecord::RecordNotFound => e
    @customer = (Customer.find_by(id: sales_order_params[:customer_id]) if params[:sales_order].present?) || current_customer
    @sales_order ||= SalesOrder.new
    @pool = DemandQuery.allocatable_lines(customer_id: @customer.id)
    flash.now[:alert] = "签发失败：#{e.message}"
    render :new, status: :unprocessable_entity
  end

  # GET /sales_orders/1/edit —— 单头编辑
  def edit
  end

  # PATCH/PUT /sales_orders/1
  def update
    if @sales_order.update(sales_order_params)
      redirect_to @sales_order, notice: "六联单已更新"
    else
      render :edit, status: :unprocessable_entity
    end
  end

  # GET /sales_orders/1/confirm —— 创建出库单
  def confirm
    @shipment = Shipment.new(sales_order: @sales_order)
  end

  # POST /sales_orders/1/create_shipment
  def create_shipment
    @shipment = Shipment.new(sales_order: @sales_order,
                             shipped_at: shipment_params[:shipped_at].presence || Time.current,
                             tracking_no: shipment_params[:tracking_no].presence,
                             note: shipment_params[:note].presence)

    shipment_params[:lines].to_h.each do |pl_id, attrs|
      qty = attrs[:quantity].to_i
      next if qty <= 0

      @shipment.shipment_lines.build(production_line_id: pl_id, quantity: qty)
    end

    if @shipment.save
      redirect_to @sales_order, notice: "出库单已创建（#{@shipment.shipment_lines.size} 行）"
    else
      flash.now[:alert] = @shipment.errors.full_messages.to_sentence
      render :confirm, status: :unprocessable_entity
    end
  end

  # GET /sales_orders/1/invoice
  def invoice
    respond_to do |format|
      format.html
      format.pdf { render pdf: "invoice-#{@sales_order.serial_number}", layout: "pdf" }
      format.json { render json: @sales_order }
    end
  end

  # GET /sales_orders/1/packing_list
  def packing_list
    respond_to do |format|
      format.html
      format.pdf { render pdf: "packing-#{@sales_order.serial_number}", layout: "pdf" }
      format.json { render json: @sales_order }
    end
  end

  # DELETE /sales_orders/1
  def destroy
    if @sales_order.destroy
      redirect_to sales_orders_url, notice: "六联单已删除"
    else
      redirect_to sales_order_url(@sales_order), alert: @sales_order.errors.full_messages.to_sentence
    end
  end

  private

  def set_sales_order
    @sales_order = SalesOrder.find(params[:id])
  end

  # 转产定型：按后缀拼正式型号（generic + suffix）；不存在就就地新建
  def resolve_item(order_line, suffix)
    suffix = suffix.to_s.strip
    Item.find_or_create_by!(generic_part_no: order_line.generic_part_no, suffix: suffix.presence) do |item|
      item.name = "#{order_line.generic_part_no}#{suffix}"
      item.index = 1
    end
  end

  def lines_params
    params.permit(lines: [:item_id, :suffix, :quantity, :version, :full_name, :remark])[:lines] || {}
  end

  def shipment_params
    params.permit(:shipped_at, :tracking_no, :note, lines: [:quantity])
  end

  def sales_order_params
    params.require(:sales_order).permit(:bill_address, :bill_contact, :bill_telephone, :customer_id,
                                        :payment_term, :ship_address, :ship_contact, :ship_telephone,
                                        :end_customer_id, :exchange_rate, :remark, :required_date)
  end
end
