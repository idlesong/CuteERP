class SalesOrder < ActiveRecord::Base
  attr_accessible :bill_address, :bill_contact, :bill_telephone, :customer_id,
  :payment_term, :serial_number, :ship_address, :ship_contact, :ship_telephone,
  :delivery_date, :delivery_status, :delivery_plan, :exchange_rate, :remark,
  :created_at

  has_many :line_items, :as => :line,  :dependent => :destroy
  belongs_to :customer

  validates :serial_number, :presence => true
  validates :bill_address, :bill_contact, :bill_telephone, :ship_contact, :ship_address,
    :ship_telephone, :presence => true
  validates :customer_id, :payment_term, :presence => true
  validates :line_items, :presence => true
  validates :exchange_rate, :presence => true #:if => usd_currency_customer?

  def generate_order_number
    next_id = SalesOrder.where(created_at: DateTime.now.at_beginning_of_day..DateTime.now.at_end_of_day ).count + 1
    order_number = 'SO' + DateTime.now.strftime("%Y%m%d") + '-' + (next_id%100).to_s.rjust(2,'0')
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

  def add_line_items_from_issue_cart(cart)
    logger.debug "==@@@@==SalesOrder: add line_items_from_cart.id==== #{cart.id}"
    cart.line_items.each_with_index do |line, index|
      # logger.debug "==@@@@==SalesOrder: add line_items.id==== #{line.id}"
      line.cart_id = nil
      line.line_number = self.serial_number + '-' + (index + 1).to_s.rjust(2,'0')
      self.line_items << line
    end
  end

  # so.line_items vs cart.line_items issue_unissue so: order.line_items.quantity_issued
  def issue_unissue_po_line_items_when_so_and_cart_diffs(issue_cart)
      logger.debug "==@@@@==SalesOrder: issue unissue(), issuce_cart.id==== #{issue_cart.id}"
      # so line_items not in cart(will be removed), issueback po
      self.line_items.each do |so_line|
        if not issue_cart.line_items.where(line_number: so_line.line_number).exists?
            logger.debug "==@@@@==line_items to be removed from so==== #{so_line.id}"
            self.issue_back_refer_line_item(so_line, so_line.quantity)
        end
      end

      # cart line_items not in so(will be added), issue po
      issue_cart.line_items.each do |line_item|
        # cart line_items not in so: to be added to so
        if not self.line_items.where(line_number: line_item.line_number).exists?
          logger.debug "==@@@@==new line, to be added to so==== #{line_item.id}"    
          self.issue_refer_line_item(line_item, line_item.quantity)         
        else # exist, but quantity different
          line = self.line_items.where(line_number: line_item.line_number).take
          logger.debug "==@@@@==exsit line, update po==== #{line_item.id}"
          if line.quantity < line_item.quantity
            self.issue_refer_line_item(line_item, line_item.quantity - line.quantity)
          elsif line.quantity > line_item.quantity
            self.issue_back_refer_line_item(line_item, line.quantity - line_item.quantity)          
          end
        end
      end
  end

  # issue refer po's line items, after save; and then clear cart
  def issue_refer_line_items
    line_items.each do |line|
      logger.debug "==@@@@==SalesOrder refer_line_id== #{line.refer_line_id}"
      po_line = LineItem.find(line.refer_line_id)
      po_line.update_attribute(:quantity_issued, po_line.quantity_issued + line.quantity)

      line.update_attribute(:cart_id, nil)
    end
  end

  def issue_refer_line_item(line_item, quantity)
      logger.debug "====@@@@==SalesOrder :issue_refer=refer_line_id== #{line_item.refer_line_id}"
      po_line = LineItem.find(line_item.refer_line_id)
      po_line.update_attribute(:quantity_issued, po_line.quantity_issued + quantity)
      # line_item.update_attribute(:cart_id, nil)
  end

  def issue_back_refer_line_item(line_item, quantity)
    logger.debug "==@@@@==SalesOrder: issue_back()refer_line_id== #{line_item.refer_line_id}"
    po_line = LineItem.find(line_item.refer_line_id)
    if quantity <= po_line.quantity_issued
      po_line.update_attribute(:quantity_issued, po_line.quantity_issued - quantity)
    else
      logger.debug "==@@@@==SalesOrder: issue_back() Error}"
    end
  end

  before_destroy :ensure_not_invoiced_or_delivered

  private
   def ensure_not_invoiced_or_delivered
   	if delivery_date.nil?
   		return true
   	else
   		errors.add(:base, 'Line Items present')
   		return false
   	end
  end

  # completed: can't update after both invoiced and shipped
end
