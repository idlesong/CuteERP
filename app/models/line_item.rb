class LineItem < ActiveRecord::Base
  attr_accessible :cart_id, :item_id, :item, :quantity, :order_id,
      :quantity_issued, :refer_line_id, :price

  belongs_to :line, :polymorphic => true
  # belongs_to :order
  # belongs_to :sales_order
  belongs_to :item
  # belongs_to :cart

  def total_price
    if price.nil?
      total_amount = 0
    else
  	  total_amount = price * quantity
    end
  end
end
