class Opportunity < ActiveRecord::Base
  attr_accessible :note, :priority, :project_type, :solution
  belongs_to :customer
  has_many :oppostatus
end
