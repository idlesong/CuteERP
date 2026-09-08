class Price < ActiveRecord::Base
  belongs_to :item
  belongs_to :customer
  belongs_to :quotation

  has_many :line_items

  validates :price, presence: true, numericality: { greater_than_or_equal_to: 0 }
  validates :condition, presence: true
  validates :part_number, presence: true
  validates :customer_name, presence: true
  validates :item_id, presence: true
  validates :customer_id, presence: true

  before_save :ensure_price_is_unique?
  before_destroy :ensure_not_used_by_others

  def generate_price_number
    next_id = Price.where(created_at: DateTime.now.at_beginning_of_day..DateTime.now.at_end_of_day).count + 1
    "QO" + DateTime.now.strftime("%Y%m%d") + (next_id % 100).to_s.rjust(2, "0")
  end

  def get_set_price(item_id, order_quantity, sell_by)
    last_set_price = SetPrice.order(released_at: :asc).last
    step_quantities = ["1", "1000", "2500", "5000", "10000", "20000", "50000", "100000"]
    oem_labels = ["step1", "step2", "step3", "step4", "step5", "step6", "step7", "step8"]
    odm_labels = ["step9", "step10", "step11", "step12", "step13", "step14", "step15", "step16"]

    step_labels = oem_labels
    step_labels = odm_labels if sell_by == "ODM"

    index = step_quantities.index(order_quantity)
    index = 1 if index.nil?

    step = step_labels.at(index)

    return unless last_set_price

    @latest_set_prices = SetPrice.order("item_id ASC").where("released_at" => last_set_price.released_at)
    if @latest_set_prices.where(item_id: item_id).first.nil?
      0
    else
      set_price = @latest_set_prices.where(item_id: item_id).first
      set_price.attributes[step]
    end
  end

  def self.export_to_csv(options = {})
    CSV.generate(**options) do |csv|
      header = ["price_number", "customer_name", "part_number", "price", "condition",
                "base_price", "extra_price", "remark", "status", "created_at"]
      csv << header

      all.each do |item|
        csv << item.attributes.values_at(*header)
      end
    end
  end

  def self.import(file)
    spreadsheet = open_spreadsheet(file)

    header = ["price_number", "customer_name", "part_number", "price", "condition",
              "base_price", "extra_price", "remark", "status", "created_at"]

    (2..spreadsheet.last_row).each do |i|
      row = Hash[[header, spreadsheet.row(i)].transpose]
      # primary key: price_number, update existing, or create new one
      price = find_by(price_number: row["price_number"]) || new
      row_attributes = row.to_hash.slice(*header)

      # part_number and customer_name are fixed; auto link to id when import
      row_attributes.store("item_id", Item.find_by(partNo: row_attributes["part_number"]).id)
      row_attributes.store("customer_id", Customer.find_by(name: row_attributes["customer_name"]).id)

      (header + ["item_id", "customer_id"]).each do |attr|
        price.update_attribute(attr, row_attributes[attr])
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

  before_destroy :price_request_approved?

  private

  def ensure_price_is_unique?
    duplicate = Price.where(customer_name: customer_name)
                     .where(part_number: part_number)
                     .where(condition: condition)
                     .where.not(id: id)
                     .first
    return if duplicate.nil?

    errors.add(:base, "price already exists for this customer/part/condition")
    throw :abort
  end

  def price_request_approved?
    return unless status_was == "approved"

    errors.add(:base, "price has been approved, cannot update!")
    throw :abort
  end

  def ensure_not_used_by_others
    return if line_items.empty?

    errors.add(:base, "line_items exist")
    throw :abort
  end
end
