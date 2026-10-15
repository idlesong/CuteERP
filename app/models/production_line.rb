# 六联单行：正式型号（item = 转产时确定后缀）+ 生产数量
# 需求来源通过 production_allocations 台账关联客户订单行（可跨单、可拆量、可调整，D2）
class ProductionLine < ApplicationRecord
  belongs_to :sales_order
  belongs_to :item, optional: true
  has_many :production_allocations, dependent: :destroy
  has_many :order_lines, through: :production_allocations
  has_many :shipment_lines, dependent: :destroy

  validates :quantity, numericality: { greater_than: 0 }
  validate :quantity_not_below_shipped, on: :update
  after_update :release_excess_allocations, if: :saved_change_to_quantity?

  # 已出库后数量只能增不能减（减少走冲销/退货）
  def quantity_not_below_shipped
    errors.add(:quantity, "不能低于已出库数量（#{shipped_qty}）") if quantity < shipped_qty
  end

  def part_number
    item&.partNo
  end

  def product_name
    item&.name || full_name
  end

  # 数量减少时，超额分配自动释放回客户订单行池（保持台账与池一致）
  def release_excess_allocations
    excess = production_allocations.sum(:quantity) - quantity
    return if excess <= 0

    production_allocations.order(id: :desc).each do |a|
      break if excess <= 0

      take = [a.quantity, excess].min
      if take == a.quantity
        a.destroy
      else
        a.update_columns(quantity: a.quantity - take)
      end
      excess -= take
    end
  end

  def shipped_qty
    shipment_lines.sum(:quantity)
  end

  def unshipped_qty
    quantity - shipped_qty
  end

  # 价格快照取自分配的客户订单行（加权平均；同型号通常同价）
  def unit_price
    allocs = production_allocations.includes(:order_line)
    return nil if allocs.empty?

    total_alloc = allocs.sum(&:quantity).to_f
    allocs.sum { |a| a.quantity * (a.order_line&.unit_price || 0) } / total_alloc
  end

  def total_price
    (unit_price || 0) * quantity
  end
end
