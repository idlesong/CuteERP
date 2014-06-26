class Task < ActiveRecord::Base
  attr_accessible :description, :status
  belongs_to :Oppostatus
end
