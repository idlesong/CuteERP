class Price < ActiveRecord::Base
  attr_accessible :boss_suggestion, :condition, :customer_id, :department_suggestion,
  :finance_suggestion, :item_id, :payment_terms, :price, :sales_suggestion, :status,
  :remark, :created_at, :base_price, :extra_price

  belongs_to :item
  belongs_to :customer
  belongs_to :quotation

  has_many :line_items

  validates :price, :presence => true, :numericality => {:greater_than_or_equal_to => 0}
  validates :item_id, :presence => true
  validates :customer_id, :presence => true

  def get_set_price(item_id, order_quantity)
    last_set_price = SetPrice.order(released_at: :asc).last
    if last_set_price  
      @latest_set_prices = SetPrice.order("item_id ASC").order("order_quantity::integer ASC")
                                   .where("released_at" => last_set_price.released_at )
      if @latest_set_prices.where(item_id: item_id, order_quantity: order_quantity).first.nil?
        return 0
      else
        return @latest_set_prices.where(item_id: item_id, order_quantity: order_quantity).first.price
      end
    end  
  end

  def self.export_to_csv(options = {})
    CSV.generate(options) do |csv|
      array = column_names.clone
      if array.include?("item_id") && array.include?("customer_id")
        item_index = array.index("item_id")
        customer_index = array.index("customer_id")
        array[array.index("item_id")] = "item_name"
        array[array.index("customer_id")] = "customer_name"
      end
      csv << array
      all.each do |item|
        row = item.attributes.values_at(*column_names)
        # logger.debug "=====csv row== #{row} index: #{item_index}"
        row[item_index] = Item.find(row[item_index]).partNo
        row[customer_index] = Customer.find(row[customer_index]).name

        csv << row
      end
    end
  end

  def self.import(file)
    spreadsheet = open_spreadsheet(file)

    header = spreadsheet.row(1)
    (2..spreadsheet.last_row).each do |i|

      row = Hash[[header, spreadsheet.row(i)].transpose]
      # primary key: full_name
      price = find(row["id"])  || new      
      price.attributes = row.to_hash.slice(*accessible_attributes)
      item_part_number = price.attributes["item_id"]
      customer_name = price.attributes["customer_id"]
      price.attributes["item_id"] = Item.find_by(name: item_part_number)
      price.attributes["customer_id"] = Customer.find_by(name: customer_name)      

      price.save!
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

  # before_update :price_request_approved?
  before_destroy :price_request_approved?

 private
  def price_request_approved?
    if status_was == 'approved'
      errors.add(:base, 'price has been approved, cannot update!')
      return false
    else
      return true
    end
  end
end
