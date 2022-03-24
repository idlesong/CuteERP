class SetPrice < ActiveRecord::Base
    attr_accessible :order_quantity, :price, :sell_by, :item_id, :released_at, :created_at
  
    belongs_to :item
  
    validates :price, :presence => true, :numericality => {:greater_than_or_equal_to => 0}
    validates :item_id, :presence => true
end
