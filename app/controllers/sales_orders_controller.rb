# 生产订单（六联单）：
# - 签发 = 从客户订单行池（DemandQuery）多选拆量 → production_lines + production_allocations（D2）
# - 生产编排 = 转产选正式型号（同 generic 组选后缀，组内没有可就地新建）
# - 发货 = 出库单 shipments（可多次，末次派生发货时间）
class SalesOrdersController < ApplicationController
  before_action :set_sales_order, only: [:show, :edit, :update, :destroy,
                                         :production, :update_production,
                                         :add_line, :remove_line,
                                         :confirm, :create_shipment, :quick_ship, :submit, :invoice, :packing_list]

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

  # PATCH /sales_orders/1/submit —— 草稿提交
  def submit
    if @sales_order.submit!
      target = params[:return_to] == "workbench" ? workbench_path : @sales_order
      redirect_to target, notice: "六联单 #{@sales_order.serial_number} 已提交"
    else
      redirect_to @sales_order, alert: @sales_order.errors.full_messages.to_sentence
    end
  end

  # PATCH /sales_orders/1/update_production
  def update_production
    lines_params.to_h.each do |id, attrs|
      line = @sales_order.production_lines.find(id)
      line.update!(item_id: attrs[:item_id].presence, quantity: attrs[:quantity],
                   version: attrs[:version].presence, full_name: attrs[:full_name].presence,
                   remark: attrs[:remark].presence)
    end
    redirect_to @sales_order, notice: "行已保存"
  rescue ActiveRecord::RecordInvalid => e
    redirect_to @sales_order, alert: e.message
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
    raise "没有数量大于 0 的行，未签发任何行" if entries.empty?

    pool_lines = entries.keys.map { |id| OrderLine.find(id) }
    # 一张六联单 = 一个型号一个价：型号或单价不一致直接报错（避免混签）
    # （注意：不能用 raise ActiveRecord::RecordInvalid, "msg" —— 其构造器把 msg 当 record 调 .errors）
    generics = pool_lines.map(&:generic_part_no).uniq
    if generics.many?
      raise "所选行通用型号不一致（#{generics.join('、')}），一张六联单只能签发同一型号"
    end
    prices = pool_lines.map(&:unit_price).uniq
    if prices.many?
      raise "所选行单价不一致（#{prices.map(&:to_s).join('、')}），请核对订单行价格后分开签发"
    end

    SalesOrder.transaction do
      entries.each do |ol_id, attrs|
        order_line = OrderLine.find(ol_id)
        item = resolve_item(order_line, attrs[:suffix])
        line = @sales_order.production_lines.build(
          item: item, suffix: attrs[:suffix].to_s.strip.presence,
          quantity: attrs[:quantity].to_i,
          version: attrs[:version].presence,
          full_name: attrs[:full_name].presence || item.name,
          remark: attrs[:remark].presence
        )
        line.production_allocations.build(order_line: order_line, quantity: attrs[:quantity].to_i)
      end
      @sales_order.save!
    end
    target = params[:return_to] == "workbench" ? workbench_path : @sales_order
    redirect_to target, notice: "六联单 #{@sales_order.serial_number} 已创建（草稿，请在列表或详情页提交）"
  rescue ActiveRecord::RecordInvalid, ActiveRecord::RecordNotFound, RuntimeError => e
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

  # POST /sales_orders/1/add_line —— 追加行：从未分配 PO 行池再签一行到本六联单（未出库即可追加）
  def add_line
    order_line = OrderLine.find(params.require(:order_line_id))
    qty = params.require(:quantity).to_i
    raise "数量必须大于 0" if qty <= 0

    # 与本单已有行保持同型号同价（一张六联单 = 一个型号一个价）
    other_generics = @sales_order.production_lines.includes(:item)
                                  .map { |pl| pl.item&.generic_part_no }.uniq - [order_line.generic_part_no]
    if other_generics.present?
      raise "本六联单已有型号 #{other_generics.join('、')} 的行，不能混签 #{order_line.generic_part_no}"
    end
    other_prices = @sales_order.production_lines.flat_map { |pl| pl.order_lines.map(&:unit_price) }
                                                .uniq - [order_line.unit_price]
    raise "本六联单已有行的单价与其不一致（#{other_prices.map(&:to_s).join('、')}），请核对" if other_prices.present?

    item = resolve_item(order_line, params[:suffix])
    line = @sales_order.production_lines.build(
      item: item, suffix: params[:suffix].to_s.strip.presence,
      quantity: qty, version: params[:version].presence,
      full_name: params[:full_name].presence || item.name
    )
    line.production_allocations.build(order_line: order_line, quantity: qty)

    if line.save
      redirect_to @sales_order, notice: "已追加 #{line.part_number} x#{qty}"
    else
      redirect_to @sales_order, alert: "追加失败：#{line.errors.full_messages.to_sentence}"
    end
  rescue ActiveRecord::RecordInvalid, ActiveRecord::RecordNotFound, RuntimeError => e
    redirect_to @sales_order, alert: "追加失败：#{e.message}"
  end

  # DELETE /sales_orders/1/remove_line?line_id= —— 删行：仅未出库行（分配随之释放回池）
  def remove_line
    line = @sales_order.production_lines.find(params.require(:line_id))
    if line.shipped_qty.positive?
      redirect_to @sales_order, alert: "该行已出库，不能删除"
      return
    end
    po_ref = line.order_lines.map(&:display_no).join(", ")
    line.destroy
    redirect_to @sales_order, notice: "已删除该行#{po_ref.present? ? "（#{po_ref} 需求已释放回池）" : ""}"
  end

  # GET /sales_orders/1/confirm —— 创建出库单
  def confirm
    if @sales_order.draft?
      redirect_to @sales_order, alert: "草稿六联单请先提交后再出库"
      return
    end
    @shipment = Shipment.new(sales_order: @sales_order)
  end

  # POST /sales_orders/1/create_shipment
  def create_shipment
    if @sales_order.draft?
      redirect_to @sales_order, alert: "草稿六联单请先提交后再出库"
      return
    end
    @shipment = Shipment.build_for(@sales_order,
                                   shipped_at: shipment_params[:shipped_at].presence || Time.current,
                                   tracking_no: shipment_params[:tracking_no].presence,
                                   note: shipment_params[:note].presence,
                                   lines_params: shipment_params[:lines].to_h)

    if @shipment.save
      target = params[:return_to] == "workbench" ? workbench_path : @sales_order
      redirect_to target, notice: "出库单已创建（#{@shipment.shipment_lines.sum(:quantity)} 件）"
    else
      flash.now[:alert] = @shipment.errors.full_messages.to_sentence
      render :confirm, status: :unprocessable_entity
    end
  end

  # POST /sales_orders/1/quick_ship —— 整单快捷出库（全部未出数量一次出完）
  def quick_ship
    if @sales_order.draft?
      redirect_to @sales_order, alert: "草稿六联单请先提交后再出库"
      return
    end
    shipment = Shipment.new(sales_order: @sales_order, shipped_at: Time.current, note: "快捷出货")
    @sales_order.production_lines.each do |pl|
      qty = pl.unshipped_qty
      shipment.shipment_lines.build(production_line: pl, quantity: qty) if qty.positive?
    end

    if shipment.save
      redirect_back fallback_location: @sales_order,
                    notice: "已快捷出库（#{@sales_order.serial_number}，共 #{shipment.shipment_lines.sum(:quantity)} 件）"
    else
      redirect_back fallback_location: @sales_order,
                    alert: "快捷出库失败：#{shipment.errors.full_messages.to_sentence}"
    end
  end

  # GET /sales_orders/1/invoice
  def invoice
    respond_to do |format|
      format.html
      format.pdf { send_data render_invoice_pdf, filename: "invoice-#{@sales_order.serial_number}.pdf", type: "application/pdf" }
      format.json { render json: @sales_order }
    end
  end

  # GET /sales_orders/1/packing_list
  def packing_list
    respond_to do |format|
      format.html
      format.pdf { send_data render_packing_pdf, filename: "packing-#{@sales_order.serial_number}.pdf", type: "application/pdf" }
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

  # wkhtmltopdf 渲染：显式套 pdf 布局（含 charset 与中文字体声明）
  def render_invoice_pdf
    html = render_to_string(template: "sales_orders/invoice", layout: "pdf", formats: [:pdf])
    WickedPdf.new.pdf_from_string(html)
  end

  def render_packing_pdf
    html = render_to_string(template: "sales_orders/packing_list", layout: "pdf", formats: [:pdf])
    WickedPdf.new.pdf_from_string(html)
  end

  def set_sales_order
    @sales_order = SalesOrder.find(params[:id])
  end

  # 转产定型：产品列表只维护通用型号，取对应 Item（未建档即失败）；后缀落 production_lines.suffix
  def resolve_item(order_line, _suffix)
    Item.find_by!(generic_part_no: order_line.generic_part_no)
  rescue ActiveRecord::RecordNotFound
    raise "型号「#{order_line.generic_part_no}」未在产品列表建档，请先维护产品"
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
