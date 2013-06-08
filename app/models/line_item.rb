class LineItem < ActiveRecord::Base
  attr_accessible :cart_id, :item_id
  belongs_to:item
  belongs_to:cart 
end
