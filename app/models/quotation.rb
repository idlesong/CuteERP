# 客户报价单：选定客户的若干报价生成一张单
# - 明细（quotation_lines）为价格快照：同一价格可进多张报价单，单据不随后续调价漂移
# - price_id 仅作追溯；不再反向占用价格记录（旧 quotation_id 方案已废弃）
class Quotation < ApplicationRecord
  belongs_to :customer
  has_many :quotation_lines, dependent: :destroy

  validates :customer_id, presence: true
  validates :quotation_number, presence: true, uniqueness: true

  # 报价单号：QT+日期+3位流水（删除安全：当日已占用号最大值递增，撞号循环）
  def self.next_number
    prefix = "QT#{Date.current.strftime('%Y%m%d')}-"
    used = where("quotation_number LIKE ?", "#{prefix}%").pluck(:quotation_number)
           .filter_map { |n| n[/\A#{prefix}(\d{3})\z/, 1]&.to_i }
    n = used.any? ? used.max + 1 : 1
    loop do
      candidate = format("%s%03d", prefix, n)
      break candidate unless exists?(quotation_number: candidate)

      n += 1
    end
  end

  # 以所选价格重建快照明细（编辑 = 重选）
  def build_lines_from(price_ids)
    quotation_lines.destroy_all
    Price.where(id: price_ids).order(:id).find_each do |pr|
      quotation_lines.create!(price: pr, part_number: pr.part_number,
                              product_name: pr.order_item&.name,
                              unit_price: pr.price, condition: pr.condition,
                              currency: pr.currency.presence || "RMB")
    end
  end
end
