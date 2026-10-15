# 月度对账单（第二阶段 2.3）：客户 × 月份
# 订单核对段 + 出货核对段；合计本币与折算 RMB 双口径（汇率经由 RevenueQuery / exchange_rates）
class MonthlyStatement
  Row = Struct.new(:date, :doc_no, :part, :quantity, :unit_price, :amount, :amount_rmb, :extra)

  attr_reader :customer, :month, :order_rows, :shipment_rows, :currency

  def initialize(customer, month)
    @customer = customer
    @month = month.beginning_of_month
    @range = @month.all_month
    @currency = customer.currency.presence || "RMB"
    @order_rows = []
    @shipment_rows = []
    build
  end

  def build
    # 订单核对段：当月创建（接收）的已提交订单行
    OrderLine.joins(:order)
             .includes(order: :customer)
             .where(orders: { kind: "normal", status: "submitted", customer_id: customer.id, created_at: @range })
             .order("orders.po_number", "order_lines.line_no").find_each do |line|
      rate = rate_for(@month, line.order.currency)
      @order_rows << Row.new(line.order.created_at.to_date, line.display_no, line.generic_part_no,
                             line.quantity, line.unit_price, line.total_price,
                             (line.total_price * rate).round(2), line.version)
    end

    # 出货核对段：当月出库明细
    ShipmentLine.joins(:shipment)
                .includes(shipment: { sales_order: :customer }, production_line: :item)
                .where(shipments: { sales_order_id: customer.id, shipped_at: @range })
                .order("shipments.shipped_at").find_each do |sl|
      pl = sl.production_line
      rate = rate_for(sl.shipment.shipped_at.beginning_of_month, @currency)
      amount = sl.quantity * (pl&.unit_price || 0)
      @shipment_rows << Row.new(sl.shipment.shipped_at.to_date, sl.shipment.sales_order.serial_number,
                                pl&.part_number, sl.quantity, pl&.unit_price || 0, amount,
                                (amount * rate).round(2), sl.shipment.tracking_no)
    end
  end

  def order_totals
    totals_for(order_rows)
  end

  def shipment_totals
    totals_for(shipment_rows)
  end

  private

  def totals_for(rows)
    { qty: rows.sum(&:quantity), amount: rows.sum(&:amount).round(2),
      amount_rmb: rows.sum(&:amount_rmb).round(2) }
  end

  def rate_for(month_date, currency)
    return 1 if currency.blank? || currency == "RMB"

    ExchangeRate.rate_for(month_date, currency) || 1
  end
end
