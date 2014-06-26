class Customer < ActiveRecord::Base
  attr_accessible :address, :balance, :contact, :name, :since, :telephone
  has_many :orders
  has_many :contacts
  has_many :opportunities

end
