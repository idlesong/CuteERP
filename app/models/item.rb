class Item < ActiveRecord::Base
  attr_accessible :imageURL, :name, :package, :partNo, :description,
    :volume, :weight, :moq, :mop ,
    :assembled, :index, :base_item, :extra_item, :group, :family

  # default_scope :order => 'name'
  # default_scope { where order: 'name'}

  FW_MARK_TYPES = ["-","S","M"]

  has_many :line_items
  has_many :orders, :through => :line_items
  has_many :prices
  has_many :set_prices

  validates :name, :partNo, :presence => true
  validates :partNo, :uniqueness => true

  before_destroy :ensure_not_referenced_by_any_line_item

  def self.export_to_csv(options = {})
    CSV.generate(options) do |csv|
      csv << column_names
      all.each do |item|
        csv << item.attributes.values_at(*column_names)
      end
    end
  end

  def self.import(file)
    spreadsheet = open_spreadsheet(file)

    # inactive all items
    Item.all.each do |item|
      item.index = 0
      item.save
    end

    header = spreadsheet.row(1)
    (2..spreadsheet.last_row).each do |i|
      row = Hash[[header, spreadsheet.row(i)].transpose]
      product = find_by_partNo(row["partNo"])  || new      
      product.attributes = row.to_hash.slice(*accessible_attributes)

      product.index = 1        
      product.save!
    end
  end

  def self.open_spreadsheet(file)
    case File.extname(file.original_filename)
    when ".csv" then Roo::CSV.new(file.path, csv_options: {encoding: "iso-8859-1:utf-8"})
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
