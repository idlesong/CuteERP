class Item < ActiveRecord::Base
  attr_accessible :imageURL, :name, :package, :partNo, :price, :description,
    :volume, :weight, :moq, :mop ,:rmb_tax_rate, :usd_tax_rate, :assembled, :index

  default_scope :order => 'name'

  FW_MARK_TYPES = ["-","S"]

  has_many :line_items
  has_many :orders, :through => :line_items
  has_many :prices

  validates :name, :partNo, :presence => true
  validates :partNo, :uniqueness => true
  validates :price, :numericality => {:greater_than_or_equal_to => 0.01}

  before_destroy :ensure_not_referenced_by_any_line_item

  def self.to_csv(options = {})
    CSV.generate(options) do |csv|
      csv << column_names
      all.each do |item|
        csv << item.attributes.values_at(*column_names)
      end
    end
  end

  def self.import(file)
    spreadsheet = open_spreadsheet(file)
    header = spreadsheet.row(1)
    (2..spreadsheet.last_row).each do |i|
      row = Hash[[header, spreadsheet.row(i)].transpose]
      product = find_by_id(row["id"]) || new
      product.attributes = row.to_hash.slice(*accessible_attributes)
      product.save!
    end
  end

  def self.open_spreadsheet(file)
    case File.extname(file.original_filename)
    when ".csv" then Csv.new(file.path, nil, :ignore)
    when ".xls" then Excel.new(file.path, nil, :ignore)
    when ".xlsx" then Excelx.new(file.path, nil, :ignore)
    else raise "Unknown file type: #{file.original_filename}"
    end
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
