class Order < ActiveRecord::Base
  has_many :line_items, as: :line,  :dependent => :destroy
  belongs_to :customer

  attr_accessible :customer_id, :amount, :order_number, :name, :address,
    :telephone, :ship_contact, :ship_address, :ship_telephone, :pay_type

  PAYMENT_TYPES = ["T.T in advance", "COD", "T.T 30days",'T.T 60days']

  # validates :name, :address, :email, :pay_type, :presence => true
  # validates :pay_type, :inclusion => PAYMENT_TYPES

  def add_line_items_from_cart(cart)
  	cart.line_items.each do |line|
  		# line.cart_id = nil
  		line_items << line
  	end
  end

  # def issue_line_item(line_id)
  #   issued_line = line_items.find(line_id)
  #   issued_line.quantity_left = 0
  #   issued_line.save
  # end

  def get_bill_to_info()
  end

  def get_ship_to_info()
  end

end
