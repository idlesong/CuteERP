class LineItem < ActiveRecord::Base
  attr_accessible :cart_id, :item_id, :quantity, :order_id,
      :quantity_issued, :refer_line_id, :price

  # validates :price, :presence => true, :numericality => {:greater_than_or_equal_to => 0.01}
  # validates :quantity,:presence => true, :numericality => {:greater_than_or_equal_to => 0.01}
  # validates :quantity_issued, :numericality => {:less_than_or_equal_to => :quantity}

  belongs_to :line, :polymorphic => true
  # belongs_to :order
  # belongs_to :sales_order
  belongs_to :item
  belongs_to :cart

  def total_price
    if price.nil?
      total_amount = 0
    else
  	  total_amount = price * quantity
    end
  end
end
