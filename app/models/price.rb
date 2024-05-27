class Price < ActiveRecord::Base
  attr_accessible :boss_suggestion, :condition, :customer_id, :department_suggestion,
  :finance_suggestion, :item_id, :payment_terms, :price, :sales_suggestion, :status,
  :remark, :created_at, :base_price, :extra_price, :price_number, :part_number, :customer_name

  belongs_to :item
  belongs_to :customer
  belongs_to :quotation

  has_many :line_items

  validates :price, :presence => true, :numericality => {:greater_than_or_equal_to => 0}
  validates :condition, :presence => true
  validates :part_number, :presence => true
  validates :customer_name, :presence => true
  validates :item_id, :presence => true
  validates :customer_id, :presence => true

  before_destroy :ensure_not_used_by_others  


  def generate_price_number
    # next_id=1
    # next_id=Price.maximum(:id).next if Price.exists?
    next_id = Price.where(created_at: DateTime.now.at_beginning_of_day..DateTime.now.at_end_of_day ).count + 1
    price_number = 'QO' + DateTime.now.strftime("%Y%m%d") + (next_id%100).to_s.rjust(2,'0')
  end

  def get_set_price(item_id, order_quantity, sell_by)
    last_set_price = SetPrice.order(released_at: :asc).last
    step_quantities = ["1", "1000", "2500", "5000", "10000",  "20000", "50000", "100000"]
    oem_labels = ["step1","step2","step3", "step4","step5", "step6", "step7", "step8"]
    odm_labels = ["step9","step10","step11", "step12","step13", "step14", "step15", "step16"]
    
    step_labels = oem_labels

    if sell_by == "ODM" 
      step_labels = odm_labels
    end

    if step_quantities.index(order_quantity).nil?
      index = 1
      # logger.debug "@@@@@@@@@@@@ step_arry order quantity== #{order_quantity}"      
    else
      index = step_quantities.index(order_quantity)
    end 

    step = step_labels.at(index)
    
    if last_set_price  
      @latest_set_prices = SetPrice.order("item_id ASC").where("released_at" => last_set_price.released_at )
      if @latest_set_prices.where(item_id: item_id).first.nil?
        return 0
      else
        # return @latest_set_prices.where(item_id: item_id, order_quantity: order_quantity, sell_by: sell_by).first.price
        set_price = @latest_set_prices.where(item_id: item_id).first

        price = set_price.attributes[step]
        # logger.debug "=====return set price== #{price}"
        return price
      end
    end  
  end

  def self.export_to_csv(options = {})
    CSV.generate(options) do |csv|
      # re-order columns
      header = ["price_number", "customer_name", "part_number", "price", "condition", 
                "base_price", "extra_price", "remark", "status", "created_at"]
      # logger.debug "=====csv header array== #{header}"
      csv << header

      all.each do |item|
        row = item.attributes.values_at(*header)
        # logger.debug "=====csv row== #{row} index: #{item_index}"
        csv << row
      end
    end
  end

  def self.import(file)
    spreadsheet = open_spreadsheet(file)

    # header = spreadsheet.row(1)
    header = ["price_number", "customer_name", "part_number", "price", "condition", 
    "base_price", "extra_price", "remark", "status", "created_at"]    

    (2..spreadsheet.last_row).each do |i|

      row = Hash[[header, spreadsheet.row(i)].transpose]
      # primary key: price_number, update exsit, or create new one
      price = find_by(price_number: row["price_number"])  || new
      row_attributes = row.to_hash.slice(*header)   
      
      # price.part_number and customer_name are fixed; auto link to id when import
      row_attributes.store("item_id", Item.find_by(partNo: row_attributes["part_number"]).id)
      row_attributes.store("customer_id", Customer.find_by(name: row_attributes["customer_name"]).id)  

      # logger.debug "=====import row_attributes== #{row_attributes}"      
      # import row according to row header
      (header + ["item_id", "customer_id"]).each do |attr|
        price.update_attribute(attr, row_attributes[attr])
      end
      # logger.debug "=====row attr== #{price.attributes[attr]}, #{row_attributes[attr]}"      
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

  def ensure_not_used_by_others
    if line_items.empty? then
  		return true
  	else
      errors.add(:base, 'line_items exist')
  		return false
  	end
  end   
end
