class Setting < ActiveRecord::Base
  attr_accessible :name, :note, :value
end
