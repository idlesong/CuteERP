# 分配台账（D2）：六联单行 ← 消耗 → 客户订单行
# 跨多个客户订单、部分/全量数量，无张数上限，事后可调整
class ProductionAllocation < ApplicationRecord
  belongs_to :production_line
  belongs_to :order_line

  validates :quantity, numericality: { greater_than: 0 }
  validate :within_allocatable_balance

  private

  # 分配不得超过该订单行的可分配余额（净需求 - 已分配）
  def within_allocatable_balance
    return if order_line.nil?

    others = order_line.production_allocations.where.not(id: id).sum(:quantity)
    balance = order_line.quantity - order_line.return_lines.sum(:quantity).abs - others
    errors.add(:quantity, "超过该订单行可分配余额（#{balance}）") if quantity > balance
  end
end
