class PriceListEntry < ApplicationRecord
  belongs_to :price_list_release

  validates :generic_part_no, :sell_by, :min_qty, :price, presence: true
  validates :min_qty, numericality: { only_integer: true, greater_than: 0 }
  # 唯一性由 DB 组合唯一索引 (price_list_release_id, generic_part_no, sell_by, min_qty) 兜底

  scope :ordered, -> { order(:generic_part_no, :sell_by, :min_qty) }

  # 指定财年批次下，某通用型号+渠道+订购数量的阶梯价（取 ≤ 数量的最高档）
  def self.tier_price(generic_part_no, sell_by, qty, release = nil)
    release ||= PriceListRelease.ordered.first
    return nil unless release

    where(price_list_release_id: release.id, generic_part_no: generic_part_no, sell_by: sell_by)
      .where("min_qty <= ?", qty.to_i)
      .order(min_qty: :desc).first&.price
  end

  # 定期 Excel 整表导入：旧 set_price_list 版式（行首 set_price_list released_at）
  # 列：0=PartNo, 1=extra, 2=(空), 3..18=OEM 8 档 + ODM 8 档
  def self.import(file, release)
    sheet = Item.open_spreadsheet(file)
    unless sheet.row(1)[0].to_s.include?("set_price_list")
      raise "格式不符：首行需为 set_price_list released_at"
    end

    qty_tiers = [1, 1000, 2500, 5000, 10000, 20000, 50000, 100000]
    count = 0

    (3..sheet.last_row).each do |i|
      row = sheet.row(i)
      item = Item.find_by_any_part_no(row[0])
      next if item.nil? || item.generic_part_no.blank?

      gen = item.generic_part_no
      16.times do |idx|
        val = row[3 + idx]
        next if val.blank? || val.to_f <= 0

        create!(
          price_list_release_id: release.id,
          generic_part_no: gen,
          sell_by: idx < 8 ? "OEM" : "ODM",
          min_qty: qty_tiers[idx % 8],
          price: val.to_f
        )
        count += 1
      end
    end
    count
  end
end
