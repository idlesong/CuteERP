class Price < ActiveRecord::Base
  attr_accessible :boss_suggestion, :condition, :customer_id, :department_suggestion,
  :finance_suggestion, :item_id, :payment_terms, :price, :sales_suggestion, :status,
  :created_at

  belongs_to :item
  belongs_to :customer

  validates :price, :presence => true, :numericality => {:greater_than_or_equal_to => 0}
  validates :item_id, :presence => true

  # before_update :price_request_approved?
  before_destroy :price_request_approved?

 private
  def price_request_approved?
    if status_was == 'approved'
      errors.add(:base, 'price has been approved, cannot update!')
      return false
    else
      return true
    end
  end
end
