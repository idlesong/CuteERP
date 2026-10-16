class PriceListEntry < ApplicationRecord
  TIERS = [1, 1000, 2500, 5000, 10000, 20000, 50000, 100000].freeze
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
  # 阶梯导入：对账模板「阶梯价格」表格式——一行一个通用型号，
  # 列 = 通用型号 | (空) | 渠道 | 8档 | 渠道 | 8档（前段 OEM、后段 ODM），空档跳过
  def self.import(file, release)
    sheet = open_tier_sheet(file)
    tiers = TIERS
    count = 0

    (2..sheet.last_row).each do |i|
      gen = sheet.cell(i, 1).to_s.strip
      next if gen.blank?

      [["OEM", 4], ["ODM", 13]].each do |channel, col0|
        tiers.each_with_index do |qty, ti|
          val = sheet.cell(i, col0 + ti)
          next if val.blank? || val.to_f <= 0

          create!(
            price_list_release_id: release.id,
            generic_part_no: gen,
            sell_by: channel,
            min_qty: qty,
            price: val.to_f
          )
          count += 1
        end
      end
    end
    count
  end

  # 在工作簿中定位阶梯表（表头含 通用型号+渠道），缺省用第一张
  def self.open_tier_sheet(file)
    sheet = Roo::Excelx.new(file.path)
    name = sheet.sheets.find do |s|
      h = (1..sheet.last_column(s)).map { |c| sheet.cell(1, c, s).to_s.strip }
      h.include?("通用型号") && h.include?("渠道")
    end
    sheet.default_sheet = name if name
    sheet
  end
end
