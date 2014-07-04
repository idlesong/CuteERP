class Opportunity < ActiveRecord::Base
  attr_accessible :note, :priority, :project_type, :solution, :customer_id
  belongs_to :customer
  has_many :oppostatuses

end
