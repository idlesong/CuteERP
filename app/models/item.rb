class Item < ActiveRecord::Base
  attr_accessible :imageURL, :name, :package, :partNo, :price, :description
  default_scope :order => 'name'

  has_many :line_items
  has_many :orders, :through => :line_items


  validates :name, :package, :partNo, :presence => true
  validates :price, :numericality => {:greater_than_or_equal_to => 0.01}
  validates :imageURL, :format => {
              :with => %r{\.(gif|jpg|png)$}i,
              :message => "must be a URL for Gif, JPG or PNG image."
              }

  before_destroy :ensure_not_referenced_by_any_line_item

 private
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
