class Item < ActiveRecord::Base
  FW_MARK_TYPES = ["", "S", "M", "D", "C"]

  has_many :production_lines
  has_many :prices

  before_validation :normalize_suffix
  before_create { self.index = 1 if index.nil? } # 新产品默认可见（index 0 = 隐藏）

  validates :name, :generic_part_no, presence: true
  validates :suffix, uniqueness: { scope: :generic_part_no }

  before_destroy :ensure_not_referenced_by_any_production_line
  before_destroy :ensure_not_used_by_others

  # 完整型号（派生）：generic_part_no + suffix（D4，partNo 列已移除）
  def partNo
    [generic_part_no, suffix].compact.join
  end

  # 完整型号拆分："TC2008ABC" => ["TC2008AB", "C"]；无字母尾缀 => [pn, nil]
  def self.split_part_no(pn)
    pn = pn.to_s.strip
    if pn[-1]&.match?(/[A-Za-z]/)
      [pn[0..-2], pn[-1]]
    else
      [pn, nil]
    end
  end

  # 兼容完整/通用两种型号的查找
  def self.find_by_any_part_no(pn)
    pn = pn.to_s.strip
    return nil if pn.blank?

    exact = find_by(generic_part_no: pn)
    return exact if exact

    base, sfx = split_part_no(pn)
    find_by(generic_part_no: base, suffix: sfx)
  end

  EXPORT_HEADERS = %w[型号 产品名称 中文名 描述 类别 产品族 base_item extra_item extra_item2
                      包装 最小起订量 组装方式 状态].freeze

  def self.export_rows
    order(:generic_part_no, :suffix).map do |i|
      [i.partNo, i.name, i.name_zh, i.description, i.group, i.family,
       i.base_item, i.extra_item, i.extra_item2,
       i.package, i.moq, i.assembled, i.index.positive? ? "active" : "隐藏"]
    end
  end

  def self.export_xlsx
    Xlsx.generate(name: "产品", headers: EXPORT_HEADERS, rows: export_rows)
  end

  def self.import(file)
    spreadsheet = open_spreadsheet(file)

    header = ["partNo", "group", "family", "name", "description",
              "package", "mop", "assembled", "base_item", "extra_item", "index"]

    (2..spreadsheet.last_row).each do |i|
      row = Hash[[header, spreadsheet.row(i)].transpose]

      # Update existing item found by unique part number, or create a new one
      base, sfx = split_part_no(row["partNo"])
      item = find_by(generic_part_no: base, suffix: sfx) || new

      item.generic_part_no = base
      item.suffix = sfx

      row_attributes = row.to_hash.slice(*header)

      header.each do |attr|
        next if attr == "partNo"

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

  def normalize_suffix
    self.suffix = suffix.presence
  end

  # 生产行引用检查
  def ensure_not_referenced_by_any_production_line
    return if production_lines.count.zero?

    errors.add(:base, "Production lines present")
    throw :abort
  end

  def ensure_not_used_by_others
    return if prices.empty?

    errors.add(:base, "prices exist")
    throw :abort
  end
end
