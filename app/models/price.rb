class Price < ActiveRecord::Base
  attr_accessible :boss_suggestion, :condition, :customer_id, :department_suggestion,
  :finance_suggestion, :item_id, :payment_terms, :price, :sales_suggestion, :status

  validates :price, :presence => true, :numericality => {:greater_than_or_equal_to => 0.01}
  validates :item_id, :presence => true

  belongs_to :item
  belongs_to :customer
end
