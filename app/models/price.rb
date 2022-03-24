class Price < ActiveRecord::Base
  attr_accessible :boss_suggestion, :condition, :customer_id, :department_suggestion,
  :finance_suggestion, :item_id, :payment_terms, :price, :sales_suggestion, :status,
  :created_at

  belongs_to :item
  belongs_to :customer

  validates :price, :presence => true, :numericality => {:greater_than_or_equal_to => 0}
  validates :item_id, :presence => true

  def get_set_price(item_id, order_quantity)
    @latest_release_set_price = SetPrice.order(released_at: :asc).last
    @latest_set_prices = SetPrice.order("item_id ASC").order("order_quantity::integer ASC").where("released_at" => @latest_release_set_price.released_at )
    if @latest_set_prices.where(item_id: item_id, order_quantity: order_quantity).first.nil?
      return 0
    else
      return @latest_set_prices.where(item_id: item_id, order_quantity: order_quantity).first.price
    end
  end

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
