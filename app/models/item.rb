class Item < ActiveRecord::Base
  attr_accessible :imageURL, :name, :package, :partNo, :price, :description
  default_scope :order => 'name'

  has_many :line_items
  has_many :orders, :through => :line_items
  has_many :prices


  validates :name, :partNo, :presence => true
  validates :price, :numericality => {:greater_than_or_equal_to => 0.01}
  validates :imageURL, :format => {
              :with => %r{\.(gif|jpg|png)$}i,
              :message => "must be a URL for Gif, JPG or PNG image."
              }

  before_destroy :ensure_not_referenced_by_any_line_item

  def self.import(file)
    # csv_text = CSV.new(file)
    # csv_text = File.read(file)
    # csv = CSV.parse(csv_text, :headers => true)
    # csv.each do |row|
    #   Item.create!(row.to_hash)
    # end
  end


 private
  #ensure that there are no line items referencing this item
  def ensure_not_referenced_by_any_line_item
  	if line_items.count.zero?
  		return true
  	else
  		errors.add(:base, 'Line Items present')
  		return false
  	end
  end
end
