class Customer < ActiveRecord::Base
  attr_accessible :address, :balance, :contact, :name, :full_name, :since, :telephone,
                  :payment ,:currency, :ship_contact, :ship_address, :ship_telephone,
                  :credit

  CURRENCY_TYPES = ['RMB', 'USD']

  has_many :orders
  has_many :sales_orders
  has_many :contacts
  has_many :opportunities
  has_many :prices
  validates :name, :presence => true, :uniqueness => true
  validates :payment, :presence => true
  validates :currency, :presence => true
  validates :currency, :inclusion => CURRENCY_TYPES

  def get_special_price(item)
    price = prices.where({item_id: item.id, status: 'approved'}).order("created_at ASC").last
    if price.nil?
      special_price = item.price
    else
      special_price = price.price
    end
  end

  def short_name
    if name =~ /\*.*\*/
      short_name = "#{$&}"
    else
      short_name = name
    end
  end

  before_save  :copy_ship_to_from_bill_to
  before_destroy :ensure_not_used_by_others

  def self.export_to_csv(options = {})
    CSV.generate(options) do |csv|
      csv << column_names
      all.each do |item|
        csv << item.attributes.values_at(*column_names)
      end
    end
  end

  def self.import(file)
    spreadsheet = open_spreadsheet(file)

    header = spreadsheet.row(1)
    (2..spreadsheet.last_row).each do |i|
      # logger.debug "=====csv row== #{spreadsheet.row(i)}"
      row = Hash[[header, spreadsheet.row(i)].transpose]
      # primary key: full_name
      customer = find_by_name(row["name"])  || new      
      customer.attributes = row.to_hash.slice(*accessible_attributes)

      customer.save!
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
    if orders.empty? and sales_orders.empty? and contacts.empty? and opportunities.empty? and prices.any? then
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
