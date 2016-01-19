class LineItem < ActiveRecord::Base
  attr_accessible :cart_id, :item_id, :item, :quantity, :order_id,
      :quantity_issued, :refer_line_id

  belongs_to :line, :polymorphic => true
  # belongs_to :order
  # belongs_to :sales_order
  belongs_to :item
  # belongs_to :cart

  def total_price
  	item.price * quantity
  end
end
