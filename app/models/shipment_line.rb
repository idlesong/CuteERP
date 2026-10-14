# 出库单行：本次出库数量（≤ 生产行未出库数量）
class ShipmentLine < ApplicationRecord
  belongs_to :shipment
  belongs_to :production_line

  validates :quantity, numericality: { greater_than: 0 }
  validate :within_unshipped_balance, if: -> { production_line.present? }

  private

  def within_unshipped_balance
    others = production_line.shipment_lines.where.not(id: id).sum(:quantity)
    balance = production_line.quantity - others
    errors.add(:quantity, "超过该生产行未出库数量（#{balance}）") if quantity > balance
  end
end
