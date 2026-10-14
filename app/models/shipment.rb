# 出库单：可多次发货；快递号仅存储不查询（想法 4）
class Shipment < ApplicationRecord
  belongs_to :sales_order
  has_many :shipment_lines, dependent: :destroy
  has_many :production_lines, through: :shipment_lines

  accepts_nested_attributes_for :shipment_lines, allow_destroy: true

  validates :shipped_at, presence: true
  validates :shipment_lines, presence: true

  before_validation { self.shipped_at ||= Time.current }
end
