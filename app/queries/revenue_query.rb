# 营业额查询：实际出货折 RMB
# 金额 = 出库数量 × 分配行加权单价（本币） × 出货当月汇率（RMB 单 = 1）
class RevenueQuery
  # 当月营业额（折 RMB）
  def self.monthly_rmb(date = Date.current)
    # 日界时间：datetime 列对 Date 端点按 UTC 午夜 cast（北京时区即当日 08:00），会漏边界单据
    range = date.beginning_of_month.beginning_of_day..date.end_of_month.end_of_day
    ShipmentLine.joins(:shipment).where(shipments: { shipped_at: range }).sum { |sl| line_amount_rmb(sl) }
  end

  # 按月序列（FY 12 个月）折 RMB 营业额
  def self.monthly_series(fy)
    SalesPlanEntry.fy_months(fy).to_h { |m| [m.beginning_of_month, monthly_rmb(m)] }
  end

  # 单行金额（折 RMB）：数量 × 单价 × 汇率
  def self.line_amount_rmb(shipment_line)
    pl = shipment_line.production_line
    return 0.0 unless pl

    unit = pl.unit_price.to_f
    return 0.0 if unit.zero?

    unit * shipment_line.quantity * exchange_rate_for(pl, shipment_line.shipment.shipped_at)
  end

  def self.exchange_rate_for(production_line, shipped_at)
    order_line = production_line.production_allocations.first&.order_line
    currency = order_line&.order&.currency || "RMB"
    return 1 if currency == "RMB"

    ExchangeRate.rate_for(shipped_at.beginning_of_month, currency) || 1
  end
end
