class SalesOrder < ActiveRecord::Base
  attr_accessible :bill_address, :bill_contact, :bill_telephone, :customer_id,
  :payment_term, :serial_number, :ship_address, :ship_contact, :ship_telephone,
  :delivery_date, :delivery_status

  has_many :line_items, :as => :line
  belongs_to :customer

  validates :bill_address, :bill_contact, :bill_telephone, :ship_contact, :ship_address,
    :ship_telephone, :presence => true
  validates :customer_id, :payment_term, :presence => true
  validates :line_items, :presence => true

  def add_line_items_from_issue_cart(cart)
    cart.line_items.each do |line|
      line.cart_id = nil
      line_items << line
    end
  end

  def generate_order_number
    next_id=SalesOrder.maximum(:id).next
    order_number = DateTime.now.strftime("%Y%m%d") + (next_id%100).to_s
  end

  # before_edit :ensure_not_invoiced_or_delivered
  # before_destroy :ensure_not_invoiced_or_delivered
  # before_confirm :ensure_not_invoiced_or_delivered
end
