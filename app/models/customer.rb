class Customer < ActiveRecord::Base
  attr_accessible :address, :balance, :contact, :name, :full_name, :since, :telephone,
                  :payment ,:currency, :ship_contact, :ship_address, :ship_telephone,
                  :credit, :sales_type, :disty_id, :territory

  CURRENCY_TYPES = ['RMB', 'USD']
  SALES_TYPES = ['OEM', 'ODM', 'Internal']

  has_many :orders
  has_many :sales_orders
  has_many :contacts
  has_many :opportunities
  has_many :prices
  has_many :quotation
  has_many :end_customers, class_name: "Customer", foreign_key: "disty_id"
  belongs_to :disty, class_name: "Customer"

  validates :name, :presence => true, :uniqueness => true
  validates :sales_type, :presence => true
  validates :payment, :presence => true
  validates :currency, :presence => true
  validates :currency, :inclusion => CURRENCY_TYPES

  before_save  :copy_ship_to_from_bill_to
  before_destroy :ensure_not_used_by_others

  def self.export_to_csv(options = {})
    CSV.generate(options) do |csv|
      header = ["territory", "name", "full_name", "sales_type", "disty_id", 
      "payment", "currency", "since", "address", "contact", "telephone", "credit"]

      csv << header
      all.each do |customer|
        csv << customer.attributes.values_at(*header)
      end
    end
  end

  def self.import(file)
    spreadsheet = open_spreadsheet(file)

    header = ["territory", "name", "full_name", "sales_type", "disty_id", 
    "payment", "currency", "since", "address", "contact", "telephone", "credit"]

    # header = spreadsheet.row(1)
    (2..spreadsheet.last_row).each do |i|
      # logger.debug "=====csv row== #{spreadsheet.row(i)}"
      row = Hash[[header, spreadsheet.row(i)].transpose]
      # find exsits by uniq name, or new customer
      customer = find_by_name(row["name"])  || new      

      row_attributes = row.to_hash.slice(*header)

      header.each do |attr|
        customer.update_attribute(attr, row_attributes[attr])
      end       
    end
  end

  def self.open_spreadsheet(file)
    case File.extname(file.original_filename)              
    when ".csv" then Roo::CSV.new(file.path)
    when ".xls" then Excel.new(file.path, nil, :ignore)
    when ".xlsx" then Excelx.new(file.path, nil, :ignore)
    else raise "Unknown file type: #{file.original_filename}"
    end
  end

 private
  #ensure that there are no line items referencing this item
  def ensure_not_used_by_others
    if orders.empty? and sales_orders.empty? and contacts.empty? and opportunities.empty? and prices.empty? then
  		return true
  	else
      errors.add(:base, 'orders,sales_orders,contacts,opportunities or prices exist')
  		return false
  	end
  end

  def copy_ship_to_from_bill_to
    self.ship_contact = contact if ship_contact.blank?
    self.ship_address = address if ship_address.blank?
    self.ship_telephone = telephone if ship_telephone.blank?
  end

end
