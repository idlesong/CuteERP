class Oppostatus < ActiveRecord::Base
  attr_accessible :issue, :status, :opportunity_id, :todo_description, :todo_status
  belongs_to :opportunity
  has_one :task #:dependent

end
