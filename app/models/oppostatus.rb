class Oppostatus < ActiveRecord::Base
  attr_accessible :issue, :status, :opportunity_id, :todo_description, :todo_status, :user_id
  belongs_to :opportunity
  belongs_to :user

  validates :user_id, :presence => true
end
