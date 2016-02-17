class Customer < ActiveRecord::Base
  attr_accessible :address, :balance, :contact, :name, :since, :telephone, :payment ,:currency

  CURRENCY_TYPES = ['RMB', 'USD']

  has_many :orders
  has_many :sales_orders
  has_many :contacts
  has_many :opportunities
  has_many :prices
  validates :name, :presence => true, :uniqueness => true
  validates :payment, :presence => true
  # validates :currency, :presence => true
  # validates :currency, :inclusion => CURRENCY_TYPES

  def get_special_price(item)
    price = prices.where(item_id: item.id).first
    if price.nil?
      special_price = item.price
    else
      special_price = price.price
    end
  end

  def short_name
    if name =~ /\*.*\*/
      short_name = "#{$&}"
    else
      short_name = name
    end
  end

end
