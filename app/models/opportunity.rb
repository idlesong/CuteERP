class Opportunity < ActiveRecord::Base
  attr_accessible :note, :priority, :project_type, :solution
end
