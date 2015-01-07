class Price < ActiveRecord::Base
  attr_accessible :boss_suggestion, :condition, :customer_id, :department_suggestion, :finance_suggestion, :item_id, :payment_terms, :price, :sales_suggestion
  belongs_to :item
  belongs_to :customer
end
