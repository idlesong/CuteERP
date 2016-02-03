class Order < ActiveRecord::Base
  has_many :line_items, as: :line,  :dependent => :destroy
  belongs_to :customer

  attr_accessible :customer_id, :amount, :order_number, :name, :address,
    :telephone, :ship_contact, :ship_address, :ship_telephone, :pay_type

  PAYMENT_TYPES = ["T.T in advance", "COD", "T.T 30days",'T.T 60days']

  validates :name, :address, :pay_type, :presence => true
  validates :pay_type, :inclusion => PAYMENT_TYPES
  # validates :customer_id, :presence => true

  def add_line_items_from_cart(cart)
  	cart.line_items.each do |line|
  		line.cart_id = nil
  		line_items << line
  	end
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
