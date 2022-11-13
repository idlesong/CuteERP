class Order < ActiveRecord::Base
  attr_accessible :customer_id, :amount, :order_number, :name, :address,
    :telephone, :ship_contact, :ship_address, :ship_telephone, :pay_type,
    :exchange_rate, :remark, :document, :created_at, :end_customer_id

  has_many :line_items, as: :line,  :dependent => :destroy
  belongs_to :customer

  PAYMENT_TYPES = ["款到发货","T.T in advance", "COD", "T.T 30days"]

  has_attached_file :document

  validates_attachment :document, :content_type => {:content_type =>
    %w(image/jpeg image/jpg image/png application/pdf application/msword
    application/vnd.openxmlformats-officedocument.wordprocessingml.document)}

  validates :order_number, :presence => true
  validates :pay_type, :presence => true
  # validates :pay_type, :inclusion => PAYMENT_TYPES
  validates :line_items, :presence => true
  validates :customer_id, :presence => true
  validates :exchange_rate, :presence => true
  # validates :name, :address, :presence => true # can fill when ship

  def initialize_order_header(new_customer)
    self.customer = new_customer
    # set bill_to and ship_to contact by default, then confirm it in sales order
    self.name      = new_customer.contact
    self.address   = new_customer.address
    self.telephone = new_customer.telephone
    self.ship_contact = new_customer.ship_contact
    self.ship_address = new_customer.ship_address
    self.ship_telephone = new_customer.ship_telephone

    self.exchange_rate = 1 #default for rmb
    self.pay_type  = new_customer.payment
    self.order_number = self.generate_order_number
  end

  def add_line_items_from_cart(cart)
  	cart.line_items.each do |line|
  		line.cart_id = nil
  		line_items << line
  	end
  end

  def generate_order_number
    next_id=1
    next_id=Order.maximum(:id).next if Order.exists?
    order_number = customer.name + DateTime.now.strftime("%Y%m%d") + (next_id%100).to_s.rjust(2,'0')
  end

  # Cancel issued order left quantity
  def cancel
  end

  before_update :not_issued?
  before_destroy :not_issued?

  # ensure this order is not issued by any of the sales order
  def not_issued?
    if line_items.where("quantity_issued > 0").exists?
      errors.add(:base, 'Order has been used by sales orders')
      return false
    end

    return true
  end

private
  # ensure not completed: canceled or all items issued
  def besure_not_completed?
  end

end
