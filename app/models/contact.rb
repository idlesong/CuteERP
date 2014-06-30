class Contact < ActiveRecord::Base
  attr_accessible :email, :mobile, :name, :note, :telephone, :title, :customer_id
  belongs_to :customer
end
