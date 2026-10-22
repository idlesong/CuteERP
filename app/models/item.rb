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

  # 命名规则严格拆分（Baseband：完整型号 = 通用型号 + 1 位后缀，或缺省）。
  # 后缀集合来自用户设置 naming.suffixes（默认 C/M/S）；末位不在集合内 → 缺省（整串即通用型号）。
  # 订单/六联单/出库链路一律用本方法；产品建档沿用宽拆分 split_part_no（非 Baseband 族）
  def self.parse_full_part_no(full)
    full = full.to_s.strip
    last = full[-1]
    if last && User.naming_suffixes.include?(last)
      [full[0..-2], last]
    else
      [full, nil]
    end
  end

  def self.full(generic, suffix) = "#{generic}#{suffix}"

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

  # 与各导入服务同构的入口（导入预检/导入中心统一调用）
  def self.call(file, imported_by:, month: nil)
    import(file, imported_by: imported_by)
  end

  # 按表头名称解析（对齐导出工作簿「产品」表；容忍空列/多余列/列序变化）
  # 预检规则：型号必填且同文件唯一；产品名称/描述/类别必填（中文名列可作为产品名称的别名）
  def self.import(file, imported_by: nil)
    sheet = open_spreadsheet(file)
    stats = { created: 0, updated: 0, skipped: 0, errors: [], warnings: [] }
    seen_generics = {}
    each_data_row(sheet) do |row, i|
      part = row["型号"].to_s.strip
      if part.blank?
        if row.values.any? { |v| v.to_s.strip.present? }
          stats[:errors] << "第#{i}行：型号必填"
          stats[:skipped] += 1
        else
          stats[:skipped] += 1
        end
        next
      end

      generic, = parse_full_part_no(part)
      if seen_generics[generic]
        stats[:errors] << "第#{i}行：通用型号「#{generic}」重复（第#{seen_generics[generic]}行已出现）"
        stats[:skipped] += 1
        next
      end
      seen_generics[generic] = i

      # 必填：产品名称（中文名列可作为其别名）/描述/类别
      missing = %w[描述 类别].select { |h| row[h].to_s.strip.blank? }
      missing.unshift("产品名称") if row["产品名称"].to_s.strip.blank? && row["中文名"].to_s.strip.blank?
      unless missing.empty?
        stats[:errors] << "第#{i}行：缺少必填字段：#{missing.join('、')}"
        stats[:skipped] += 1
        next
      end

      # 兼容：整串精确命中旧数据；新存一律按命名规则派生通用型号（产品列表只维护通用型号）
      item = Item.all.find { |i| i.partNo == part }
      if item.nil?
        generic, = parse_full_part_no(part)
        item = new(generic_part_no: generic)
      end
      item.name = row["产品名称"].presence || row["中文名"].presence || item.name
      item.name_zh = row["产品名称"].presence || row["中文名"].presence || item.name_zh
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
      is_new = item.new_record?
      item.save!
      is_new ? stats[:created] += 1 : stats[:updated] += 1
    rescue StandardError => e
      stats[:errors] << "第#{i}行：#{e.message}"
      stats[:skipped] += 1
    end

    Import.create!(kind: "items", filename: file.original_filename,
                   imported_by: imported_by, stats: stats)
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
