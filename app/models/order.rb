class Order < ActiveRecord::Base
  has_many :line_items, as: :line,  :dependent => :destroy
  belongs_to :customer

  attr_accessible :customer_id, :amount, :order_number, :name, :address,
    :telephone, :ship_contact, :ship_address, :ship_telephone, :pay_type

  PAYMENT_TYPES = ["T.T in advance", "COD", "T.T 30days",'T.T 60days']

  validates :name, :address, :pay_type, :presence => true
  validates :pay_type, :inclusion => PAYMENT_TYPES

  validates :line_items, :presence => true
  validates :customer_id, :presence => true

  def copy_customer_info_to_order(new_customer)
    customer = new_customer
    # set bill_to and ship_to contact by default, then confirm it in sales order
    name      = ship_contact = new_customer.contact
    address   = ship_address = new_customer.address
    telephone = ship_telephone = new_customer.telephone
    pay_type  = new_customer.payment
  end

  def add_line_items_from_cart(cart)
  	cart.line_items.each do |line|
  		line.cart_id = nil
  		line_items << line
  	end
  end

  def generate_order_number
    next_id=Order.maximum(:id).next
    order_number = DateTime.now.strftime("%Y%m%d") + (next_id%100).to_s
  end

  # Cancel issued order left quantity
  def cancel
  end

  # before_edit :ensure_not_issued_by_sales_order
  # before_destroy :ensure_not_issued_by_sales_order

 private
  # ensure ensure this order is not issued by any of the sales order
  def ensure_not_issued_by_sales_order
    line_items.each do |line|
      if line.quantity_issued > 0
        errors.add(:base, 'Order has been used by sales orders')
        return false
      end
    end

    return true
  end

end
