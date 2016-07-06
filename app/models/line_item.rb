class LineItem < ActiveRecord::Base
  attr_accessible :cart_id, :item_id, :quantity, :order_id,
      :quantity_issued, :refer_line_id, :price, :full_part_number, :full_name

  validates :price, :presence => true, :numericality => {:greater_than_or_equal_to => 0}
  validates :quantity,:presence => true, :numericality => {:greater_than_or_equal_to => 1}
  validates :quantity_issued, :numericality => {:less_than_or_equal_to => :quantity}

  belongs_to :line, :polymorphic => true
  # belongs_to :order
  # belongs_to :sales_order
  belongs_to :item
  belongs_to :cart

  # default price is in RMB, currency_price:exchange_with_tax
  def show_currency_price(exchange_rate, customer_currency)
    if(customer_currency == 'USD')
      final_price = price/(1+item.rmb_tax_rate)*(1+item.usd_tax_rate)/exchange_rate
    else
      final_price = price
    end
  end

  def total_price
    if price.nil?
      total_amount = 0
    else
  	  total_amount = price * quantity
    end
  end

  def total_currency_price(exchange_rate, customer_currency)
    unit_price = show_currency_price(exchange_rate, customer_currency)
  	total_amount = unit_price * quantity
  end

  before_destroy :ensure_not_used_by_locked_orders

 private
  # ensure ensure this order is not issued by any of the sales order
  def ensure_not_used_by_locked_orders
    return false if quantity_issued > 0 #or refer_line_id

    return true
  end

end
