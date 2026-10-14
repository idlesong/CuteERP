# 年度销售计划条目（P5）：fy + customer + 大类(items.group) + 财年月 唯一
# FY 止年标记：FY2027 = 2026-04 ~ 2027-03
# 币别不单设维度：按 customer.currency 派生人民币/美元分节，汇总均折 RMB
class SalesPlanEntry < ApplicationRecord
  belongs_to :customer

  validates :fy, :product_group, :month, presence: true
  validates :month, uniqueness: { scope: [:fy, :customer_id, :product_group] }
  validates :quantity, numericality: { only_integer: true, greater_than_or_equal_to: 0 }, allow_nil: true

  scope :fiscal, ->(fy) { where(fy: fy) }
  scope :rmb_section, -> { joins(:customer).where(customers: { currency: [nil, "RMB"] }) }
  scope :usd_section, -> { joins(:customer).where(customers: { currency: "USD" }) }

  def total_amount
    (chip_amount || 0) + (software_amount || 0)
  end

  # ---- 财年工具 ----
  def self.fiscal_year(date = Date.current)
    date.month >= 4 ? date.year + 1 : date.year
  end

  def self.current_fy
    fiscal_year(Date.current)
  end

  # FY 的 12 个月首日：四月 ~ 次年三月
  def self.fy_months(fy)
    (0..11).map { |i| Date.new(fy - 1, 4, 1) >> i }
  end

  def self.fy_range(fy)
    Date.new(fy - 1, 4, 1)..(Date.new(fy, 3, 1).end_of_month)
  end

  # upsert：同 (fy, customer, group, month) 直接更新
  def self.upsert_entry!(attrs)
    entry = find_or_initialize_by(fy: attrs[:fy], customer_id: attrs[:customer_id],
                                  product_group: attrs[:product_group], month: attrs[:month])
    entry.quantity = attrs[:quantity]
    entry.chip_amount = attrs[:chip_amount]
    entry.software_amount = attrs[:software_amount]
    entry.save!
    entry
  end

  # 计划矩阵：{product_group => {customer_name => {月首日 => 度量值}}}
  def self.matrix(fy, metric: :quantity)
    fiscal(fy).includes(:customer).each_with_object({}) do |e, h|
      ((h[e.product_group] ||= {})[e.customer.name] ||= {})[e.month.beginning_of_month] = e.public_send(metric).to_f
    end
  end

  # ---- Plan.xlsx 导入 ----
  # 版式：货币段（人民币/美元）→ 大类行 → 客户行（12 个月数字；24 列=数量+芯片额；36 列=+软件额）
  # 各级合计行不导入；客户名按 name / full_name / name_zh 匹配；大类与 items.group 匹配
  # 返回 {imported:, warnings:[]}
  def self.import!(file, fy: current_fy)
    sheet = open_spreadsheet(file)
    currency = "RMB"
    group = nil
    groups = Item.where.not(group: nil).distinct.pluck(:group)
    imported = 0
    warnings = []

    (1..sheet.last_row).each do |i|
      row = sheet.row(i).map { |c| c.to_s.strip }
      cells = row.reject(&:blank?)
      next if cells.empty?

      joined = cells.join("|")
      if joined =~ /人民币|RMB/i
        currency = "RMB"
        next
      elsif joined =~ /美元|USD/i
        currency = "USD"
        next
      end
      next if cells.any? { |c| c =~ /合计|总计|total/i }

      first = cells.first.strip
      if groups.include?(first)
        group = first
        next
      end
      next if group.nil? # 大类出现前的表头等

      numbers = row.map { |c| c.to_s.strip.gsub(/[,%，]/, "") }
                   .select { |c| c =~ /\A\d+(\.\d+)?\z/ }.map(&:to_f)
      next if numbers.empty?

      customer = Customer.find_by(name: first) || Customer.find_by(full_name: first) ||
                 Customer.find_by(name_zh: first)
      unless customer
        warnings << "第#{i}行：找不到客户「#{first}」"
        next
      end
      if currency == "USD" && customer.currency != "USD"
        warnings << "第#{i}行：客户「#{first}」非美元客户，但出现在美元段（按客户币别归入人民币段）"
      end

      measures = numbers.each_slice(12).to_a
      fy_months(fy).each_with_index do |m, mi|
        qty   = measures.dig(0, mi) || 0
        chip  = measures.dig(1, mi) || 0
        soft  = measures.dig(2, mi) || 0
        next if qty.zero? && chip.zero? && soft.zero?

        upsert_entry!(fy: fy, customer_id: customer.id, product_group: group,
                      month: m, quantity: qty.to_i, chip_amount: chip, software_amount: soft)
        imported += 1
      end
    end
    { imported: imported, warnings: warnings }
  end

  def self.open_spreadsheet(file)
    case File.extname(file.original_filename)
    when ".csv" then Roo::CSV.new(file.path)
    when ".xls" then Roo::Excel.new(file.path, file_warning: :ignore)
    when ".xlsx" then Roo::Excelx.new(file.path, file_warning: :ignore)
    else raise "Unknown file type: #{file.original_filename}"
    end
  end
end
