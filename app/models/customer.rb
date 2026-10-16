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

  # 按表头名称解析（对齐导出工作簿「客户」表；容忍空列/多余列/列序变化）
  def self.import(file)
    sheet = open_spreadsheet(file)
    each_data_row(sheet) do |row|
      name = row["英文名"].to_s.strip
      next if name.blank?

      customer = find_by(name: name) || new(name: name)
      customer.name_zh = row["中文名"].presence || customer.name_zh
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
      customer.save!
    end
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
      yield row
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
