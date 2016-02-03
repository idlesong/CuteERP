class SalesOrder < ActiveRecord::Base
  attr_accessible :bill_address, :bill_contact, :bill_telephone, :customer_id,
  :payment_term, :serial_number, :ship_address, :ship_contact, :ship_telephone

  # validates :bill_address, :bill_contact, :bill_telephone, :ship_contact, :ship_address,
    # :ship_telephone, :presence => true

  # validates :customer_id, :payment_term, :serial_number, :presence => true

  has_many :line_items, :as => :line
  belongs_to :customer

  # issue customer order line_items
  # sales order line_items<< cart line_items
  def add_line_items_from_issue_cart(cart)
    cart.line_items.each do |line|
      line.cart_id = nil
      line_items << line
    end
  end

  # before_edit :ensure_not_invooced_or_delivered
  # before_destroy :ensure_not_invooced_or_delivered
end
