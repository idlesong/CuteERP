# 客户订单行：唯一编号 = order.po_number + line_no（如 IBM2006001-1）
# 行号在 PO 内自增（max+1），删除行不回收编号（被生产订单/台账引用，不可变）
# 冲销行：quantity 为负，refer_order_line_id 指向被冲销的正数行（D1）
# 签发关系：production_allocations 台账（D2），已签发/可分配均由台账聚合派生
class OrderLine < ApplicationRecord
  belongs_to :order
  belongs_to :price, optional: true # 价格快照来源（对账/追溯用；price_id 列）
  has_many :return_lines, class_name: "OrderLine", foreign_key: :refer_order_line_id
  has_many :production_allocations, dependent: :destroy
  has_many :production_lines, through: :production_allocations
  belongs_to :refer_line, class_name: "OrderLine", foreign_key: :refer_order_line_id, optional: true, counter_cache: false

  validates :generic_part_no, :quantity, presence: true
  validates :line_no, presence: true, uniqueness: { scope: :order_id }
  validates :quantity, numericality: { greater_than: 0 }, if: -> { order&.kind == "normal" }
  validate :return_quantity_within_balance, if: -> { order&.kind == "return" }

  before_validation :assign_line_no, on: :create
  before_validation :derive_generic_from_full

  # 客户所订完整型号（full_part_no）→ 按命名规则派生 generic_part_no（订单行不落后缀，
  # 后缀在六联单转产时定型；派生出的客户所订后缀经 ordered_suffix 提供默认值）
  def derive_generic_from_full
    return if full_part_no.blank?

    self.generic_part_no, = Item.parse_full_part_no(full_part_no)
  end

  # 客户所订后缀（由 full_part_no 派生，不落库；无后缀/不适用 → nil）
  def ordered_suffix
    Item.parse_full_part_no(full_part_no)[1] if full_part_no.present?
  end

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

  # 已出货数量（对账口径）：按分配比例分摊各生产行的出库。
  # as_of 给定时只计该时点前的出库（核对快照口径：由远及近封存，未来出库不得污染历史）
  def delivered_qty(as_of: nil)
    total = production_allocations.sum(:quantity)
    return 0 if total.zero?

    production_allocations.includes(production_line: :shipment_lines)
                          .sum { |a| shipped_share(a, as_of) }.round(2)
  end

  # 未交数量 = 数量 - 冲销 - 已出货
  def open_qty(as_of: nil)
    quantity - returned_qty - delivered_qty(as_of: as_of)
  end

  private

  def shipped_share(allocation, as_of = nil)
    pl = allocation.production_line
    return 0 if pl.nil? || pl.quantity.to_i.zero?

    shipped = if as_of
                pl.shipment_lines.joins(:shipment)
                  .where(shipments: { shipped_at: ..as_of }).sum(:quantity)
              else
                pl.shipped_qty
              end
    (shipped * allocation.quantity.to_f / pl.quantity).round(2)
  end

  # 构建行并从客户可用报价快照价格成分；无报价则留空（后续可手工补）
  def self.build_with_price_snapshot(order, attrs)
    line = order.order_lines.build(attrs)
    line.derive_generic_from_full # 完整型号输入时先派生通用型号，价格按通用型号匹配
    apply_price_snapshot(line)
    line
  end

  # 就地快照：行尚无成分价格时按 客户+型号+数量档位+有效期 匹配报价（Price.match_for）。
  # total = 订单实际含税单价：与报价一致（容差 0.01）直接用报价成分；
  # 不一致（砍价/调价）按报价成分比例缩放，保证三成分之和恰等于订单单价。
  # 本客户无报价时退一步用同型号其他客户的报价（调用方可凭 price_id 比对客户给出警告）
  def self.apply_price_snapshot(line, total: nil, date: Date.current)
    return line if line.base_price.present? || line.v1_price.present? || line.v2_price.present?

    price = Price.match_for(customer: line.order&.customer, part_number: line.generic_part_no,
                            quantity: line.quantity, date: date, currency: line.order&.currency) ||
            Price.match_for(part_number: line.generic_part_no, quantity: line.quantity, date: date)
    return line unless price

    comps =
      if total.present? && price.price.present? && (total.to_d - price.price.to_d).abs > 0.01
        price.split_amount(total)
      else
        [price.base_price, price.v1_price, price.v2_price]
      end
    line.assign_attributes(base_price: comps[0], v1_price: comps[1],
                           v2_price: comps[2], price_id: price.id)
    line
  end

  # ---- 展示/转产辅助 ----
  public

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

    # 总冲销（不含自身旧值 + 本次值）不得超过原行数量 —— 重复导入同一冲销行幂等
    total = refer_line.return_lines.where.not(id: id).sum(:quantity).abs + quantity.abs
    errors.add(:quantity, "冲销数量超过可冲销余额（#{refer_line.reversible_qty}）") if total > refer_line.quantity
  end
end
