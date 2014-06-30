class Oppostatus < ActiveRecord::Base
  attr_accessible :issue, :status, :opportunity_id
  belongs_to :opportunity
  has_many :task
end
