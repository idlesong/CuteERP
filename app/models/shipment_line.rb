# 出库单行：本次出库数量（≤ 生产行未出库数量）
class ShipmentLine < ApplicationRecord
  belongs_to :shipment
  belongs_to :production_line

  validates :quantity, numericality: { greater_than: 0 }
  validate :within_unshipped_balance, if: -> { production_line.present? }

  # RMB 含税单价：分配加权客户订单价 × 汇率（外币按出库当月汇率；与月度工作簿同口径）
  def unit_price_rmb
    pl = production_line
    return 0 if pl.nil?

    currency = pl.production_allocations.first&.order_line&.order&.currency || "RMB"
    rate = currency == "RMB" ? 1 : (ExchangeRate.rate_for(shipment.shipped_at.beginning_of_month, currency) || 1)
    ((pl.unit_price || 0) * rate).round(2)
  end

  # 销售额（不含税 RMB）= 数量 × 含税单价 ÷ 1.13
  def amount_ex_tax
    (quantity * unit_price_rmb / MonthlyWorkbook::TAX_FACTOR).round(2)
  end

  private

  def within_unshipped_balance
    others = production_line.shipment_lines.where.not(id: id).sum(:quantity)
    balance = production_line.quantity - others
    errors.add(:quantity, "超过该生产行未出库数量（#{balance}）") if quantity > balance
  end
end
