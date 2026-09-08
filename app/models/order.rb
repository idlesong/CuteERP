class Order < ActiveRecord::Base
  has_many :line_items, as: :line, dependent: :destroy
  belongs_to :customer

  PAYMENT_TYPES = ["款到发货", "T.T in advance", "COD", "T.T 30days"]

  include DocumentAttachment

  validates :order_number, presence: true
  validates :pay_type, presence: true
  # validates :pay_type, inclusion: PAYMENT_TYPES
  validates :line_items, presence: true
  validates :customer_id, presence: true
  validates :exchange_rate, presence: true
  # validates :name, :address, presence: true # can fill when ship

  # before_update :not_issued?
  before_destroy :not_issued?

  def initialize_order_header(new_customer)
    self.customer = new_customer
    # set bill_to and ship_to contact by default, then confirm it in sales order
    self.name = new_customer.contact
    self.address = new_customer.address
    self.telephone = new_customer.telephone
    self.ship_contact = new_customer.ship_contact
    self.ship_address = new_customer.ship_address
    self.ship_telephone = new_customer.ship_telephone

    self.exchange_rate = 1 # default for rmb
    self.pay_type = new_customer.payment
    self.order_number = generate_order_number
  end

  def add_line_items_from_cart(cart, reverse_order)
    cart.line_items.each_with_index do |line, index|
      line.cart_id = nil
      line.line_number = order_number + "-" + (index + 1).to_s.rjust(2, "0")

      if line.quantity < 0
        if reverse_order
          # issue po order before create reverse po
          po_line = LineItem.find(line.refer_line_id)
          po_line.update_attribute(:quantity_issued, po_line.quantity_issued - line.quantity)
          line.quantity_issued = line.quantity
        else
          return
        end
      end

      line_items << line
    end
  end

  def generate_order_number
    next_id = Order.where(created_at: DateTime.now.at_beginning_of_day..DateTime.now.at_end_of_day).count + 1
    "PO" + DateTime.now.strftime("%Y%m%d") + "-" + (next_id % 100).to_s.rjust(2, "0")
  end

  # Cancel issued order left quantity
  def cancel
  end

  def self.export_to_csv(options = {})
    order_header = ["order_number", "customer_id", "end_customer_id", "po_number", "created_at"]
    line_item_header = ["line_number", "full_part_number", "fixed_price", "quantity", "quantity_issued", "remark"]

    CSV.generate(**options) do |csv|
      csv << order_header + line_item_header

      all.each do |order|
        row_order_info = order.attributes.values_at(*order_header)
        row_order_info[1] = Customer.find(row_order_info[1]).name if Customer.find(row_order_info[1])
        if row_order_info[2] && Customer.find(row_order_info[2])
          row_order_info[2] = Customer.find(row_order_info[2]).name
        end

        order.line_items.each do |line_item|
          row_line_item = line_item.attributes.values_at(*line_item_header)

          csv << (row_order_info + row_line_item)
        end
      end
    end
  end

  def self.import(file)
    spreadsheet = open_spreadsheet(file)

    order_header = ["order_number", "customer_id", "end_customer_id", "po_number", "created_at"]
    line_item_header = ["line_number", "full_part_number", "fixed_price",
                        "quantity", "quantity_issued", "remark"]
    header = order_header + line_item_header

    (2..spreadsheet.last_row).each do |i|
      row = Hash[[header, spreadsheet.row(i)].transpose]
      # primary key: line_number, update existing, or create new one
      line_item = LineItem.find_by(line_number: row["line_number"]) || LineItem.new

      row_attributes = row.to_hash.slice(*header)
      # update order_header attr
      if line_item.line_type.nil?
        # line_item.build_order
      elsif line_item.line_type == "Order"
        order_header.each do |attr|
          line_item_order = Order.find(line_item.line_id)

          if (customer = Customer.find_by(name: row_attributes["customer_id"]))
            row_attributes.store("customer_id", customer.id)
          end
          if (end_customer = Customer.find_by(name: row_attributes["end_customer_id"]))
            row_attributes.store("end_customer_id", end_customer.id)
          end
          line_item_order.update_attribute(attr, row_attributes[attr])
        end
      end

      # update line_item_header attr
      line_item_header.each do |attr|
        line_item.update_attribute(attr, row_attributes[attr])
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

  # ensure this order is not issued by any of the sales order
  def not_issued?
    return unless line_items.where("quantity_issued > 0").exists?

    errors.add(:base, "Order has been used by sales orders")
    throw :abort
  end
end
