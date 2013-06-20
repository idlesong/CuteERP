class LineItem < ActiveRecord::Base
  attr_accessible :cart_id, :item_id, :item, :quantity, :cart 
  belongs_to:order
  belongs_to:item
  belongs_to:cart 

  def total_price
  	item.price * quantity
  end
end
