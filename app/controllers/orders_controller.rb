# 客户订单（P3）：
# - 单据主标识 = 客户订单号 po_number；行唯一编号 = po_number + line_no
# - 快速创建（列表页 tfoot）：相同 po_number 追加行到同一张单，行号自动 +1
# - 草稿态（D10）：新建即 draft，show 页加行，submit 后进入签发池
# - 冲销（D1）：kind=return 的单据，行引用原行、数量为负
class OrdersController < ApplicationController
  before_action :set_order, only: [:show, :edit, :update, :destroy, :submit, :new_return, :create_return]

  # GET /orders
  def index
    @lines = OrderLine.joins(:order)
                      .includes(order: [:customer, :end_customer])
                      .where(orders: { kind: "normal" })
                      .order("orders.po_number", "order_lines.line_no")

    respond_to do |format|
      format.html
      format.json { render json: @orders }
      format.csv { send_data Order.export_to_csv }
      format.xls { send_data Order.export_to_csv(col_sep: "\t") }
    end
  end

  # GET /orders/1
  def show
    @generic_options = priced_generic_options(@order.customer)
  end

  # GET /orders/next_line_no?po_number=IBM2006001
  def next_line_no
    po = params[:po_number].to_s.strip
    order = Order.find_by(po_number: po)
    if order
      render json: { exists: true, line_no: order.next_line_no, display_no: "#{po}-#{order.next_line_no}",
                     customer_id: order.customer_id, end_customer_id: order.end_customer_id,
                     currency: order.currency, status: order.status, kind: order.kind }
    else
      render json: { exists: false, display_no: "#{po}-1" }
    end
  end

  # GET /orders/new —— 高级创建（完整单头字段）
  def new
    @order = Order.build_with_customer(current_customer, po_number: params[:po_number])
    @order.snapshot_exchange_rate!
    @customers = Customer.order(:name)
  end

  # POST /orders          —— 高级创建
  # POST /orders?inline=1 —— 快速创建（tfoot 行）
  def create
    return create_inline if params[:inline]

    @order = Order.build_with_customer(Customer.find(order_params[:customer_id]))
    @order.assign_attributes(order_params.except(:customer_id))
    @order.snapshot_exchange_rate!

    if @order.save
      redirect_to @order, notice: "草稿订单 #{@order.po_number} 已创建，请在详情页添加行"
    else
      @customers = Customer.order(:name)
      render :new, status: :unprocessable_entity
    end
  end

  # GET /orders/1/edit —— 编辑单头
  def edit
    @customers = Customer.order(:name)
  end

  # PATCH/PUT /orders/1
  def update
    if @order.update(order_params)
      redirect_to @order, notice: "订单已更新"
    else
      @customers = Customer.order(:name)
      render :edit, status: :unprocessable_entity
    end
  end

  # PATCH /orders/1/submit —— 草稿提交
  def submit
    if @order.submit!
      target = params[:return_to] == "workbench" ? workbench_path : @order
      redirect_to target, notice: "订单 #{@order.po_number} 已提交"
    else
      redirect_to @order, alert: @order.errors.full_messages.to_sentence
    end
  end

  # GET /orders/1/new_return —— 冲销：选行录数量
  def new_return
    if @order.return? || @order.draft?
      redirect_to @order, alert: "草稿单和冲销单不能再冲销"
      return
    end
    @returnable = @order.order_lines.select { |l| l.reversible_qty.positive? }
    redirect_to @order, alert: "该订单没有可冲销余额" if @returnable.empty?
  end

  # POST /orders/1/create_return
  def create_return
    base_po = @order.po_number
    seq = Order.where(kind: "return").where("po_number LIKE ?", "#{base_po}-%").count + 1
    return_order = Order.new(kind: "return", status: "submitted", po_number: "#{base_po}-R#{seq}",
                             customer: @order.customer, end_customer_id: @order.end_customer_id,
                             currency: @order.currency, exchange_rate: @order.exchange_rate,
                             pay_type: @order.pay_type, name: @order.name, address: @order.address,
                             ship_contact: @order.ship_contact, ship_address: @order.ship_address,
                             ship_telephone: @order.ship_telephone, remark: "冲销 #{@order.po_number}")

    lines_params.to_h.each do |line_id, attrs|
      source = @order.order_lines.find(line_id)
      qty = attrs[:quantity].to_i
      next if qty <= 0

      return_order.order_lines.build(generic_part_no: source.generic_part_no,
                                     base_price: source.base_price, v1_price: source.v1_price,
                                     v2_price: source.v2_price, price_id: source.price_id,
                                     quantity: -qty, refer_order_line_id: source.id,
                                     remark: attrs[:remark].presence || "冲销 #{source.display_no}")
    end

    if return_order.save
      redirect_to return_order, notice: "冲销单 #{return_order.po_number} 已生成"
    else
      redirect_to new_return_order_path(@order), alert: return_order.errors.full_messages.to_sentence
    end
  end

  # POST /orders/import
  def import
    Order.import(params[:file])
    redirect_to orders_url, notice: "Orders imported."
  end

  # DELETE /orders/1
  def destroy
    po = @order.po_number
    if @order.destroy
      redirect_to orders_url, notice: "订单 #{po} 已删除"
    else
      redirect_to order_url(@order), alert: @order.errors.full_messages.to_sentence
    end
  end

  private

  def set_order
    @order = Order.find(params[:id])
  end

  # 快速创建：PO 已存在（草稿或已提交）→ 追加行；不存在 → 按所选客户建草稿单
  # 价格必须从已批准/生效价格中选择（price_id），服务端校验型号一致后快照成分
  def create_inline
    po = params.dig(:order, :po_number).to_s.strip
    raise "客户订单号不能为空" if po.blank?

    order = Order.transaction do
      found = Order.lock.find_by(po_number: po)
      if found.nil?
        customer = Customer.find_by(id: params.dig(:order, :customer_id)) || current_customer
        found = Order.build_with_customer(customer, po_number: po)
        found.snapshot_exchange_rate!
        found.save!
      end
      found
    end

    line = order.order_lines.new(line_params.except(:price_id))
    if (price = Price.find_by(id: params.dig(:order, :price_id)))
      raise "所选价格与型号不符" unless price.part_number == line.generic_part_no
      line.assign_attributes(base_price: price.base_price, v1_price: price.v1_price,
                             v2_price: price.v2_price, price_id: price.id)
    else
      OrderLine.apply_price_snapshot(line)
    end
    line.save!
    target = params[:return_to] == "workbench" ? workbench_path : orders_url
    redirect_to target, notice: "#{line.display_no} 已创建（#{order.status == 'draft' ? '草稿' : '已提交'}单追加行）"
  rescue ActiveRecord::RecordInvalid, ActiveRecord::RecordNotFound, RuntimeError => e
    redirect_to orders_url, alert: "快速创建失败：#{e.message}"
  end

  # 客户有可用报价的通用型号 + 全部产品型号，用于行选择
  def priced_generic_options(customer)
    priced = Price.available.where(customer_id: customer.id).distinct.pluck(:part_number)
    all = Item.where.not(generic_part_no: nil).distinct.pluck(:generic_part_no)
    (priced | all).sort
  end

  def line_params
    params.require(:order).permit(:generic_part_no, :quantity, :version, :required_delivery_date,
                                  :base_price, :v1_price, :v2_price, :remark)
  end

  def lines_params
    params.permit(lines: [:quantity, :remark])[:lines] || {}
  end

  def order_params
    params.require(:order).permit(:customer_id, :end_customer_id, :po_number, :name, :address, :telephone,
                                  :ship_contact, :ship_address, :ship_telephone, :pay_type,
                                  :exchange_rate, :remark)
  end
end
