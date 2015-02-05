class Contact < ActiveRecord::Base
  attr_accessible :email, :mobile, :name, :note, :telephone, :title, :customer_id, :address
  belongs_to :customer

  validates :name, :presence => true
end
