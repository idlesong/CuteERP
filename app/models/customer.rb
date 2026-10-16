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

  def self.import(file)
    spreadsheet = open_spreadsheet(file)

    header = ["territory", "name", "full_name", "sales_type", "disty_id",
              "payment", "currency", "since", "address", "contact", "telephone", "credit"]

    (2..spreadsheet.last_row).each do |i|
      row = Hash[[header, spreadsheet.row(i)].transpose]

      # find existing by unique name, or create a new customer
      customer = find_by_name(row["name"]) || new

      row_attributes = row.to_hash.slice(*header)

      header.each do |attr|
        customer.update_attribute(attr, row_attributes[attr])
      end
    end
  end

  def self.open_spreadsheet(file)
    case File.extname(file.original_filename)
    when ".csv" then Roo::CSV.new(file.path)
    when ".xls" then Roo::Excel.new(file.path, file_warning: :ignore)
    when ".xlsx" then Roo::Excelx.new(file.path, file_warning: :ignore)
    else raise "Unknown file type: #{file.original_filename}"
    end
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
