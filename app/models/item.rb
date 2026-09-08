class Item < ActiveRecord::Base
  FW_MARK_TYPES = ["", "S", "M", "D", "C"]

  has_many :line_items
  has_many :orders, through: :line_items
  has_many :prices
  has_many :set_prices

  validates :name, :partNo, presence: true
  validates :partNo, uniqueness: true

  before_destroy :ensure_not_referenced_by_any_line_item
  before_destroy :ensure_not_used_by_others

  def self.export_to_csv(options = {})
    CSV.generate(**options) do |csv|
      header = ["partNo", "group", "family", "name", "description",
                "package", "mop", "assembled", "base_item", "extra_item", "index"]

      csv << header
      all.each do |item|
        csv << item.attributes.values_at(*header)
      end
    end
  end

  def self.import(file)
    spreadsheet = open_spreadsheet(file)

    header = ["partNo", "group", "family", "name", "description",
              "package", "mop", "assembled", "base_item", "extra_item", "index"]

    (2..spreadsheet.last_row).each do |i|
      row = Hash[[header, spreadsheet.row(i)].transpose]

      # Update existing item found by unique partNo, or create a new one
      item = find_by(partNo: row["partNo"]) || new

      row_attributes = row.to_hash.slice(*header)

      header.each do |attr|
        item.update_attribute(attr, row_attributes[attr])
      end
    end
  end

  def self.open_spreadsheet(file)
    case File.extname(file.original_filename)
    when ".csv" then Roo::CSV.new(file.path, csv_options: { encoding: "iso-8859-1:utf-8" })
    when ".xls" then Roo::Excel.new(file.path, file_warning: :ignore)
    when ".xlsx" then Roo::Excelx.new(file.path, file_warning: :ignore)
    else raise "Unknown file type: #{file.original_filename}"
    end
  end

  private

  # ensure that there are no line items referencing this item
  def ensure_not_referenced_by_any_line_item
    return if line_items.count.zero?

    errors.add(:base, "Line Items present")
    throw :abort
  end

  def ensure_not_used_by_others
    return if prices.empty? && set_prices.empty?

    errors.add(:base, "prices or set_prices exist")
    throw :abort
  end
end
