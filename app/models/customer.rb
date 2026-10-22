class Customer < ActiveRecord::Base
  CURRENCY_TYPES = ["RMB", "USD"]
  SALES_TYPES = ["OEM", "ODM", "Internal"]

  has_many :orders
  has_many :sales_orders
  has_many :contacts
  has_many :opportunities
  has_many :prices
  has_many :quotation
  has_many :end_customers, class_name: "Customer", foreign_key: "disty_id"
  belongs_to :disty, class_name: "Customer"

  validates :name, presence: true, uniqueness: true
  before_validation { self.payment ||= "款到发货" }
  validates :sales_type, presence: true
  validates :currency, presence: true
  validates :currency, inclusion: CURRENCY_TYPES

  before_save :copy_ship_to_from_bill_to
  before_destroy :ensure_not_used_by_others

  EXPORT_HEADERS = %w[英文名 中文名 公司全称 区域 销售类型 代理商 币别 付款方式
                      联系人 电话 地址 收货联系人 收货地址 收货电话 建立日期 信用额].freeze

  def self.export_rows
    includes(:disty).order(:name).map do |c|
      [c.name, c.name_zh, c.full_name, c.territory, c.sales_type, c.disty&.name,
       c.currency, c.payment, c.contact, c.telephone, c.address,
       c.ship_contact, c.ship_address, c.ship_telephone, c.since&.to_date, c.credit]
    end
  end

  def self.export_xlsx
    Xlsx.generate(name: "客户", headers: EXPORT_HEADERS, rows: export_rows)
  end

  # 与各导入服务同构的入口（导入预检/导入中心统一调用）
  def self.call(file, imported_by:, month: nil)
    import(file, imported_by: imported_by)
  end

  # 按表头名称解析（对齐导出工作簿「客户」表；容忍空列/多余列/列序变化）
  # 预检规则：英文名/公司全称/销售类型/币别必填；中文名唯一（不与其他客户冲突）
  def self.import(file, imported_by: nil)
    sheet = open_spreadsheet(file)
    stats = { created: 0, updated: 0, skipped: 0, errors: [], warnings: [] }
    seen_name_zh = {}
    each_data_row(sheet) do |row, i|
      name = row["英文名"].to_s.strip
      if name.blank?
        if row.values.any? { |v| v.to_s.strip.present? }
          stats[:errors] << "第#{i}行：英文名必填"
          stats[:skipped] += 1
        else
          stats[:skipped] += 1
        end
        next
      end

      missing = %w[公司全称 销售类型 币别].select { |h| row[h].to_s.strip.blank? }
      unless missing.empty?
        stats[:errors] << "第#{i}行：缺少必填字段：#{missing.join('、')}"
        stats[:skipped] += 1
        next
      end

      name_zh = row["中文名"].to_s.strip
      if name_zh.present?
        if (dup = where(name_zh: name_zh).where.not(name: name).first)
          stats[:errors] << "第#{i}行：中文名「#{name_zh}」已被客户「#{dup.name}」使用"
          stats[:skipped] += 1
          next
        end
        # 同文件内：中文名已由其他英文名占用
        if seen_name_zh[name_zh] && seen_name_zh[name_zh][:name] != name
          stats[:errors] << "第#{i}行：中文名「#{name_zh}」与本文件第#{seen_name_zh[name_zh][:row]}行的客户冲突"
          stats[:skipped] += 1
          next
        end
        seen_name_zh[name_zh] = { name: name, row: i }
      end

      customer = find_by(name: name) || new(name: name)
      customer.name_zh = name_zh.presence || customer.name_zh
      customer.full_name = row["公司全称"].presence || customer.full_name
      customer.territory = row["区域"].presence || customer.territory
      customer.sales_type = row["销售类型"].presence || customer.sales_type
      customer.disty = Customer.find_by(name: row["代理商"].to_s.strip) if row["代理商"].present?
      customer.contact = row["联系人"].presence || customer.contact
      customer.telephone = row["电话"].presence || customer.telephone
      customer.address = row["地址"].presence || customer.address
      customer.ship_contact = row["收货联系人"].presence || customer.ship_contact
      customer.ship_address = row["收货地址"].presence || customer.ship_address
      customer.ship_telephone = row["收货电话"].presence || customer.ship_telephone
      customer.currency = row["币别"].presence || customer.currency
      customer.payment = row["付款方式"].presence || customer.payment
      is_new = customer.new_record?
      customer.save!
      is_new ? stats[:created] += 1 : stats[:updated] += 1
    rescue StandardError => e
      stats[:errors] << "第#{i}行：#{e.message}"
      stats[:skipped] += 1
    end

    Import.create!(kind: "customers", filename: file.original_filename,
                   imported_by: imported_by, stats: stats)
  end
  # 通用：按表头名称逐行解析（跳过空表头列），容忍列序变化/多余列
  def self.each_data_row(sheet, &block)
    headers = (1..sheet.last_column).map { |c| sheet.cell(1, c).to_s.strip }
    (2..sheet.last_row).each do |i|
      row = {}
      headers.each_with_index do |h, ci|
        next if h.empty?

        row[h] = sheet.cell(i, ci + 1)
      end
      yield row, i
    end
  end

  def self.open_spreadsheet(file)
    sheet = case File.extname(file.original_filename)
            when ".csv" then Roo::CSV.new(file.path)
            when ".xls" then Roo::Excel.new(file.path, file_warning: :ignore)
            when ".xlsx" then Roo::Excelx.new(file.path, file_warning: :ignore)
            else raise "Unknown file type: #{file.original_filename}"
            end
    sheet.default_sheet = "客户" if sheet.sheets.include?("客户")
    sheet
  end

  private

  # ensure that this customer is not referenced by other records
  def ensure_not_used_by_others
    return if orders.empty? && sales_orders.empty? && contacts.empty? && opportunities.empty? && prices.empty?

    errors.add(:base, "orders, sales_orders, contacts, opportunities or prices exist")
    throw :abort
  end

  def copy_ship_to_from_bill_to
    self.ship_contact = contact if ship_contact.blank?
    self.ship_address = address if ship_address.blank?
    self.ship_telephone = telephone if ship_telephone.blank?
  end
end
