class SalesOrder < ActiveRecord::Base
  attr_accessible :bill_address, :bill_contact, :bill_telephone, :customer_id,
  :payment_term, :serial_number, :ship_address, :ship_contact, :ship_telephone,
  :delivery_date, :delivery_status, :exchange_rate

  has_many :line_items, :as => :line
  belongs_to :customer

  validates :bill_address, :bill_contact, :bill_telephone, :ship_contact, :ship_address,
    :ship_telephone, :presence => true
  validates :customer_id, :payment_term, :presence => true
  validates :line_items, :presence => true
  validates :exchange_rate, :presence => true #:if => usd_currency_customer?

  def add_line_items_from_issue_cart(cart)
    cart.line_items.each do |line|
      line_items << line
    end
  end

  def generate_order_number
    next_id=1
    next_id=SalesOrder.maximum(:id).next if SalesOrder.exists?
    order_number = DateTime.now.strftime("%Y%m%d") + (next_id%100).to_s.rjust(2,'0')
  end

  def initialize_order_header(new_customer)
    self.customer = new_customer
    self.payment_term = new_customer.payment
    self.bill_contact   = new_customer.contact
    self.bill_address   = new_customer.address
    self.bill_telephone = new_customer.telephone
    self.ship_contact   = new_customer.ship_contact
    self.ship_address   = new_customer.ship_address
    self.ship_telephone = new_customer.ship_telephone

    # self.exchange_rate  = 1
    self.serial_number = self.generate_order_number
  end

  before_destroy :ensure_not_invoiced_or_delivered

  private
   def ensure_not_invoiced_or_delivered
   	unless delivery_date.nil?
   		return true
   	else
   		errors.add(:base, 'Line Items present')
   		return false
   	end
  end
end
