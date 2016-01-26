class Customer < ActiveRecord::Base
  attr_accessible :address, :balance, :contact, :name, :since, :telephone, :payment
  has_many :orders
  has_many :sales_orders
  has_many :contacts
  has_many :opportunities
  has_many :prices
  # validates :name, :presence => true, :uniqueness => true

  def get_special_price(item)
    price = prices.where(item_id: item.id).first
    if price.nil?
      special_price = item.price
    else
      special_price = price.price
    end
  end

end
