class Opportunity < ActiveRecord::Base
  attr_accessible :note, :priority, :project_type, :solution, :customer_id
  belongs_to :customer
  has_many :oppostatuses

  validates :customer_id, :project_type, :presence => true

  def market
    if solution =~ /\[.*\]/
      market = "#{$&}"
    else
      market = ''
    end
  end

end
