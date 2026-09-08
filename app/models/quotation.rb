class Quotation < ActiveRecord::Base
  belongs_to :customer
  has_many :prices

  validates :customer_id, presence: true

  def generate_quotation_number
    next_id = 1
    next_id = Quotation.maximum(:id).next if Quotation.exists?
    "NO" + DateTime.now.strftime("%Y%m%d") + (next_id % 100).to_s.rjust(2, "0")
  end

  def get_items_overview
    overview = ""
    prices.each do |price|
      overview = overview + price.item.partNo + ";"
    end
    overview
  end
end
