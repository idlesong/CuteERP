# 月度所有客户内部对账单（销售内部核对用）：
# 三段式同 MonthlyStatement（订单核对/出货核对/未交订单），但跨全部客户合成，
# 排序 = 币别 → 客户名称 → 产品大类 → 日期 → 单据号；金额按 芯片/声码1/声码2 成分拆分分别显示。
# 单价与金额一律本币（币别列区分），折 RMB 仅在合计列；段合计跨币别只给 RMB 口径
class InternalMonthlyStatement
  Row = Struct.new(:date, :doc_no, :customer, :currency, :part, :group, :quantity,
                   :chip_price, :v1_price, :v2_price,
                   :chip_amt, :v1_amt, :v2_amt, :amount, :rate, :amount_rmb, :extra)

  attr_reader :month, :order_rows, :shipment_rows, :backlog_rows

  def initialize(month)
    @month = month.beginning_of_month
    @range = @month.all_month
    @order_rows = []
    @shipment_rows = []
    @backlog_rows = []
    build_orders
    build_backlog
    build_shipments
    sort_rows!
  end

  def build_orders
    OrderLine.joins(order: :customer)
             .includes(order: :customer)
             .where(orders: { kind: "normal", status: "submitted", created_at: @range })
             .order("orders.po_number", "order_lines.line_no").find_each do |line|
      rate = rate_for(@month, line.order.currency)
      qty = line.quantity
      chip = (qty * (line.base_price || 0)).round(2)
      v1 = (qty * (line.v1_price || 0)).round(2)
      v2 = (qty * (line.v2_price || 0)).round(2)
      @order_rows << Row.new(line.order.created_at.to_date, line.display_no,
                             cust_name(line.order.customer), line.order.currency,
                             line.generic_part_no, line.order_item&.group, qty,
                             line.base_price || 0, line.v1_price || 0, line.v2_price || 0,
                             chip, v1, v2, line.total_price.round(2), rate,
                             (line.total_price * rate).round(2), line.version)
    end
  end

  def build_backlog
    cutoff = @range.last.end_of_day
    OrderLine.joins(order: :customer)
             .includes(order: :customer)
             .where(orders: { kind: "normal", status: "submitted", created_at: Date.new(1970, 1, 1)..cutoff })
             .order("orders.po_number", "order_lines.line_no").find_each do |line|
      open = line.open_qty
      next if open <= 0

      rate = rate_for(cutoff.beginning_of_month, line.order.currency)
      chip = (open * (line.base_price || 0)).round(2)
      v1 = (open * (line.v1_price || 0)).round(2)
      v2 = (open * (line.v2_price || 0)).round(2)
      @backlog_rows << Row.new(cutoff.to_date, line.display_no,
                               cust_name(line.order.customer), line.order.currency,
                               line.generic_part_no, line.order_item&.group, open,
                               line.base_price || 0, line.v1_price || 0, line.v2_price || 0,
                               chip, v1, v2, line.unit_price * open, rate,
                               (line.unit_price * open * rate).round(2), line.version)
    end
  end

  def build_shipments
    # 成分单价与月度工作簿出库单同口径：分配加权的 芯片/声码1/声码2（本币）
    ShipmentLine.joins(shipment: { sales_order: :customer })
                .includes(shipment: { sales_order: :customer },
                          production_line: { item: [], production_allocations: { order_line: :order } })
                .where(shipments: { shipped_at: @range })
                .order("shipments.shipped_at").find_each do |sl|
      pl = sl.production_line
      currency = pl&.production_allocations&.first&.order_line&.order&.currency || "RMB"
      rate = rate_for(sl.shipment.shipped_at.beginning_of_month, currency)
      allocs = pl&.production_allocations || []
      total_alloc = allocs.sum(&:quantity).to_f
      if total_alloc.positive?
        chip_p = allocs.sum { |a| a.quantity * (a.order_line&.base_price || 0).to_f } / total_alloc
        v1_p = allocs.sum { |a| a.quantity * (a.order_line&.v1_price || 0).to_f } / total_alloc
        v2_p = allocs.sum { |a| a.quantity * (a.order_line&.v2_price || 0).to_f } / total_alloc
      else
        chip_p = v1_p = v2_p = 0.0
      end
      qty = sl.quantity
      unit = (pl&.unit_price || 0).round(2)
      @shipment_rows << Row.new(sl.shipment.shipped_at.to_date, sl.shipment.sales_order.serial_number,
                                cust_name(sl.shipment.sales_order.customer), currency,
                                pl&.part_number, pl&.item&.group, qty,
                                chip_p.round(2), v1_p.round(2), v2_p.round(2),
                                (qty * chip_p).round(2), (qty * v1_p).round(2), (qty * v2_p).round(2),
                                (qty * unit).round(2), rate,
                                (qty * unit * rate).round(2), sl.shipment.tracking_no)
    end
  end

  # 段合计（本币金额跨币别无意义，合计一律折 RMB）
  def totals_for(rows)
    {
      qty: rows.sum(&:quantity),
      chip_rmb: rows.sum { |r| r.chip_amt * r.rate }.round(2),
      v1_rmb: rows.sum { |r| r.v1_amt * r.rate }.round(2),
      v2_rmb: rows.sum { |r| r.v2_amt * r.rate }.round(2),
      amount_rmb: rows.sum(&:amount_rmb).round(2)
    }
  end

  def order_totals = totals_for(order_rows)
  def shipment_totals = totals_for(shipment_rows)
  def backlog_totals = totals_for(backlog_rows)

  HEADERS = %w[币别 客户 单据号 日期 产品 产品大类 数量
               芯片单价 声码1单价 声码2单价
               芯片金额 声码1金额 声码2金额 金额合计 汇率 折RMB合计 附加].freeze

  def to_rows(rows)
    rows.map { |r| [r.currency, r.customer, r.doc_no, r.date, r.part, r.group, r.quantity,
                    r.chip_price, r.v1_price, r.v2_price,
                    r.chip_amt, r.v1_amt, r.v2_amt, r.amount, r.rate, r.amount_rmb, r.extra] }
  end

  private

  def sort_rows!
    key = ->(r) { [r.currency, r.customer, r.group.to_s, r.date, r.doc_no] }
    @order_rows.sort_by!(&key)
    @shipment_rows.sort_by!(&key)
    @backlog_rows.sort_by!(&key)
  end

  def cust_name(customer)
    customer.name_zh.presence || customer.name
  end

  def rate_for(month_date, currency)
    return 1 if currency.blank? || currency == "RMB"

    ExchangeRate.rate_for(month_date, currency) || 1
  end
end
