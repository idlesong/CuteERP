class Opportunity < ActiveRecord::Base
  belongs_to :customer
  has_many :oppostatuses

  validates :customer_id, :project_type, presence: true

  def market
    if solution =~ /\[.*\]/
      "#{$&}"
    else
      ""
    end
  end
end
