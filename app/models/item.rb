class Item < ActiveRecord::Base
  attr_accessible :imageURL, :name, :package, :partNo, :price
  default_scope :order => 'name'

  has_many:line_items

  #before_destory:ensure_not_referenced_by_any_line_item
  #ensure that there are no line items referencing this item
  def ensure_not_referenced_by_any_line_item
  	if line_items.count.zero?
  		return true
  	else
  		errors.add(:base, 'Line Items present')
  		return false
  	end
  end
end
