class Item < ActiveRecord::Base
  FW_MARK_TYPES = ["", "S", "M", "D", "C"]

  has_many :production_lines
  has_many :prices

  before_validation :normalize_suffix
  before_create { self.index = 1 if index.nil? } # 新产品默认可见（index 0 = 隐藏）

  validates :name, :generic_part_no, presence: true
  validates :suffix, uniqueness: { scope: :generic_part_no }

  before_destroy :ensure_not_referenced_by_any_production_line

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

  # 按表头名称解析（对齐导出工作簿「产品」表；容忍空列/多余列/列序变化）
  def self.import(file)
    sheet = open_spreadsheet(file)
    each_data_row(sheet) do |row|
      part = row["型号"].to_s.strip
      next if part.blank?

      # 优先按完整型号精确匹配（后缀长度任意）；仅全新型号才走兜底拆分新建
      item = Item.all.find { |i| i.partNo == part }
      if item.nil?
        base, sfx = split_part_no(part)
        item = new(generic_part_no: base, suffix: sfx.presence)
        item.generic_part_no = base
        item.suffix = sfx
      end
      item.name = row["产品名称"].presence || item.name
      item.description = row["描述"].presence || item.description
      item.group = row["类别"].presence || item.group
      item.family = row["产品族"].presence || item.family
      item.assembled = row["组装方式"].presence || item.assembled
      item.base_item = row["base_item"].presence || item.base_item
      item.extra_item = row["extra_item"].presence || item.extra_item
      item.extra_item2 = row["extra_item2"].presence || item.extra_item2
      item.package = row["包装"].presence || item.package
      item.moq = row["最小起订量"].presence || item.moq
      item.index = row["状态"] == "隐藏" ? 0 : 1
      item.save!
    end
  end
  # 通用：按表头名称逐行解析（跳过空表头列），容忍列序变化/多余列
  def self.each_data_row(sheet, &block)
    headers = (1..sheet.last_column).map { |c| sheet.cell(1, c).to_s.strip }
    (2..sheet.last_row).each do |i|
      row = {}
      headers.each_with_index do |h, ci|
        next if h.empty?

        row[h] = sheet.cell(i, ci + 1)
      end
      yield row, i
    end
  end

  def self.open_spreadsheet(file)
    sheet = case File.extname(file.original_filename)
            when ".csv" then Roo::CSV.new(file.path)
            when ".xls" then Roo::Excel.new(file.path, file_warning: :ignore)
            when ".xlsx" then Roo::Excelx.new(file.path, file_warning: :ignore)
            else raise "Unknown file type: #{file.original_filename}"
            end
    sheet.default_sheet = "产品" if sheet.sheets.include?("产品")
    sheet
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

end
