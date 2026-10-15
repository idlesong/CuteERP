# 客户订单行：唯一编号 = order.po_number + line_no（如 IBM2006001-1）
# 行号在 PO 内自增（max+1），删除行不回收编号（被生产订单/台账引用，不可变）
# 冲销行：quantity 为负，refer_order_line_id 指向被冲销的正数行（D1）
# 签发关系：production_allocations 台账（D2），已签发/可分配均由台账聚合派生
class OrderLine < ApplicationRecord
  belongs_to :order
  has_many :return_lines, class_name: "OrderLine", foreign_key: :refer_order_line_id
  has_many :production_allocations, dependent: :destroy
  has_many :production_lines, through: :production_allocations
  belongs_to :refer_line, class_name: "OrderLine", foreign_key: :refer_order_line_id, optional: true, counter_cache: false

  validates :generic_part_no, :quantity, presence: true
  validates :line_no, presence: true, uniqueness: { scope: :order_id }
  validates :quantity, numericality: { greater_than: 0 }, if: -> { order&.kind == "normal" }
  validate :return_quantity_within_balance, if: -> { order&.kind == "return" }

  before_validation :assign_line_no, on: :create

  def display_no
    order ? "#{order.po_number}-#{line_no}" : line_no.to_s
  end

  # 单价（本币）= 三成分之和（D3）
  def unit_price
    (base_price || 0) + (v1_price || 0) + (v2_price || 0)
  end

  def total_price
    unit_price * quantity
  end

  # 已冲销数量
  def returned_qty
    return_lines.sum(:quantity).abs
  end

  # 已分配（签发）数量 —— 台账聚合（仅统计已提交六联单；草稿单不占池）
  def allocated_qty
    production_allocations
      .joins(production_line: :sales_order)
      .where(sales_orders: { status: "submitted" })
      .sum(:quantity)
  end

  # 净需求 = 数量 - 冲销（DemandQuery 口径）
  def net_qty
    quantity - returned_qty
  end

  # 可分配余额 = 净需求 - 已分配
  def allocatable_qty
    net_qty - allocated_qty
  end

  # 剩余数量（列表显示口径）= 可分配
  def quantity_left
    allocatable_qty
  end

  # 可冲销余额 = 原行数量 - 已被冲销数量
  def reversible_qty
    quantity - returned_qty
  end

  # 已出货数量（对账口径）：按分配比例分摊各生产行的出库
  def delivered_qty
    total = production_allocations.sum(:quantity)
    return 0 if total.zero?

    production_allocations.includes(production_line: :shipment_lines)
                          .sum { |a| shipped_share(a) }.round(2)
  end

  # 未交数量 = 数量 - 冲销 - 已出货
  def open_qty
    quantity - returned_qty - delivered_qty
  end

  private

  def shipped_share(allocation)
    pl = allocation.production_line
    return 0 if pl.nil? || pl.quantity.to_i.zero?

    (pl.shipped_qty * allocation.quantity.to_f / pl.quantity).round(2)
  end

  # 构建行并从客户可用报价快照价格成分；无报价则留空（后续可手工补）
  def self.build_with_price_snapshot(order, attrs)
    line = order.order_lines.build(attrs)
    apply_price_snapshot(line)
    line
  end

  # 就地快照：行尚无成分价格时按客户+型号取可用报价
  def self.apply_price_snapshot(line)
    return line if line.base_price.present? || line.v1_price.present? || line.v2_price.present?

    price = Price.available.find_by(customer_id: line.order.customer_id, part_number: line.generic_part_no) ||
            Price.available.where(part_number: line.generic_part_no).order(:condition).first
    return line unless price

    line.assign_attributes(base_price: price.base_price, v1_price: price.v1_price,
                           v2_price: price.v2_price, price_id: price.id)
    line
  end

  # ---- 展示/转产辅助 ----
  def order_item
    Item.find_by(generic_part_no: generic_part_no)
  end

  def full_part_number
    order_item&.partNo || generic_part_no
  end

  # 供生产端选择正式型号：同通用型号组内的 item（= 选后缀）
  def item_candidates
    Item.where(generic_part_no: generic_part_no).order(:suffix)
  end

  private

  def assign_line_no
    self.line_no ||= order.next_line_no if order
  end

  def return_quantity_within_balance
    return if refer_line.nil?

    errors.add(:quantity, "冲销数量超过可冲销余额（#{refer_line.reversible_qty}）") if quantity.abs > refer_line.reversible_qty
  end
end
