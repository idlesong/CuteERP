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

  # 已分配（签发）数量 —— 台账聚合
  def allocated_qty
    production_allocations.sum(:quantity)
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

  # 从客户可用报价快照价格成分；无报价则留空（后续可手工补）
  def self.build_with_price_snapshot(order, attrs)
    line = order.order_lines.build(attrs)
    if line.base_price.nil? && line.v1_price.nil? && line.v2_price.nil?
      price = Price.available.find_by(customer_id: order.customer_id, part_number: line.generic_part_no) ||
              Price.available.where(part_number: line.generic_part_no).order(:condition).first
      if price
        line.base_price = price.base_price
        line.v1_price = price.v1_price
        line.v2_price = price.v2_price
        line.price_id = price.id
      end
    end
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
