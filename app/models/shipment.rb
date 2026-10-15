# 出库单：可多次发货；快递号仅存储不查询（想法 4）
class Shipment < ApplicationRecord
  belongs_to :sales_order
  has_many :shipment_lines, dependent: :destroy
  has_many :production_lines, through: :shipment_lines

  accepts_nested_attributes_for :shipment_lines, allow_destroy: true

  validates :shipped_at, presence: true
  validates :shipment_lines, presence: true

  before_validation { self.shipped_at ||= Time.current }

  attr_accessor :overflow_message

  validate :no_overflow

  # build_for 顺序填充时的溢出标记（save 校验会重置手工 errors，须走 validate）
  def no_overflow
    errors.add(:base, overflow_message) if overflow_message
  end

  # 构建出库单：
  # - lines_params: { production_line_id => quantity } 逐行指定
  # - total_qty:    总数量，按行顺序填充（快捷出货）
  # - 均空:         整单出完
  def self.build_for(sales_order, shipped_at: nil, tracking_no: nil, note: nil,
                     lines_params: {}, total_qty: nil)
    shipment = new(sales_order: sales_order,
                   shipped_at: shipped_at.presence || Time.current,
                   tracking_no: tracking_no.presence, note: note.presence)
    if lines_params.present?
      lines_params.each do |pl_id, attrs|
        qty = attrs[:quantity].to_i
        shipment.shipment_lines.build(production_line_id: pl_id, quantity: qty) if qty.positive?
      end
    elsif total_qty
      left = total_qty
      sales_order.production_lines.order(:id).each do |pl|
        break if left <= 0

        take = [pl.unshipped_qty, left].min
        if take.positive?
          shipment.shipment_lines.build(production_line: pl, quantity: take)
          left -= take
        end
      end
      shipment.overflow_message = "数量超过全部未出库数量（缺 #{left}）" if left.positive?
    else
      sales_order.production_lines.each do |pl|
        qty = pl.unshipped_qty
        shipment.shipment_lines.build(production_line: pl, quantity: qty) if qty.positive?
      end
    end
    shipment
  end
end
