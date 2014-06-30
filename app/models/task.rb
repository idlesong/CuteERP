class Task < ActiveRecord::Base
  attr_accessible :description, :status, :oppostatus_id
  belongs_to :Oppostatus
end
