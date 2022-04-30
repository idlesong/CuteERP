class Quotation < ActiveRecord::Base
  # attr_accessible :remark, :quotation_number, :customer_id, :prices_id
  belongs_to :customer  
  has_many :prices
  # accepts_nested_attributes_for :prices, allow_destroy: true

  validates :customer_id, :presence => true

  def generate_quotation_number
    next_id=1
    next_id=Quotation.maximum(:id).next if Quotation.exists?
    quotation_number = "NO" + DateTime.now.strftime("%Y%m%d") + (next_id%100).to_s.rjust(2,'0')
  end

  def get_items_overview
    overview = ""
    self.prices.each do |price|
      overview = overview + price.item.partNo + ";"
    end
    return overview
  end
end
