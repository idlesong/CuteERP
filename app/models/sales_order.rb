class SalesOrder < ActiveRecord::Base
  attr_accessible :bill_address, :bill_contact, :bill_telephone, :customer_id,
  :payment_term, :serial_number, :ship_address, :ship_contact, :ship_telephone,
  :serial_number

  has_many :line_items, :as => :line
  belongs_to :customer

  # issue customer order line_items
  # sales order line_items<< cart line_items
  def add_line_items_from_issue_cart(cart)
    cart.line_items.each do |line|
      # line.cart_id = nil
      line_items << line
    end
  end
end
