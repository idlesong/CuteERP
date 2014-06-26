class Oppostatus < ActiveRecord::Base
  attr_accessible :issue, :status
  belongs_to :opportunity
  has_many :task
end
