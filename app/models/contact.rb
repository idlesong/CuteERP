class Contact < ActiveRecord::Base
  attr_accessible :email, :mobile, :name, :note, :telephone, :title
  belongs_to :customer
end
