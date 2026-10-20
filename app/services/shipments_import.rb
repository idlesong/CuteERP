require "roo"

# 出库单批量导入（第三阶段）：
# - 模板 = 月度工作簿「出库单」表（日期/客户/六联单号/产品/数量/快递号；金额列导入忽略）
# - 行按（六联单号+日期+快递号）分组为一张出库单，同单同产品多行数量累加
# - 幂等键 source_key = serial|date|tracking：重导整单重建行（Excel 为准，D14 同源）
# - 校验报告：六联单不存在 / 产品未匹配 / 客户不符 / 超未出库余额
class ShipmentsImport
  def self.call(file, imported_by:, month: nil)
    sheet = open_spreadsheet(file)
    idx = header_index(sheet)
    raise "无法识别出库单表头：缺少「六联单号」列" if idx["六联单号"].nil?

    stats = { created: 0, updated: 0, skipped: 0, errors: [], warnings: [] }
    groups = collect_groups(sheet, idx, stats)

    groups.each do |(serial, date, tracking), group|
      so = SalesOrder.find_by(serial_number: serial)
      unless so
        stats[:errors] << "第#{group[:rows].first}行：六联单「#{serial}」不存在（请先导入六联单）"
        stats[:skipped] += 1
        next
      end

      sheet_customers = group[:customers].map(&:to_s).map(&:strip).uniq.reject(&:blank?)
      if sheet_customers.any? && sheet_customers.none? { |c| c == so.customer.name || c == so.customer.name_zh }
        stats[:warnings] << "第#{group[:rows].first}行：客户「#{sheet_customers.join('/')}」与六联单「#{serial}」的客户（#{so.customer.name_zh.presence || so.customer.name}）不符，按六联单客户处理"
      end

      source_key = "#{serial}|#{date}|#{tracking}"
      shipment = Shipment.find_by(source_key: source_key) ||
                 Shipment.new(sales_order: so, shipped_at: date || Time.current,
                              tracking_no: tracking.presence, source_key: source_key)
      is_new = shipment.new_record?

      begin
        line_qty = match_lines(so, group, serial, stats)
        if line_qty.empty?
          stats[:skipped] += 1
          next
        end

        shipment.shipment_lines.destroy_all
        line_qty.each { |pl, qty| shipment.shipment_lines.build(production_line: pl, quantity: qty) }
        shipment.save!
        is_new ? stats[:created] += 1 : stats[:updated] += 1
      rescue ActiveRecord::RecordInvalid => e
        stats[:errors] << "第#{group[:rows].first}行：六联单「#{serial}」出库失败：#{e.message}"
        stats[:skipped] += 1
      end
    end

    Import.create!(kind: "shipments", month: month, filename: file.original_filename,
                   imported_by: imported_by, stats: stats)
  end

  # 按行收集分组：[serial, date, tracking] => { qty_by_part, customers, rows }
  def self.collect_groups(sheet, idx, stats)
    groups = {}
    (2..sheet.last_row).each do |i|
      val = ->(name) { idx[name] ? formatted(sheet.cell(i, idx[name])) : "" }
      serial = val.call("六联单号").to_s.strip
      part = val.call("产品").to_s.strip
      qty = val.call("数量").to_i
      if serial.blank? && part.blank?
        stats[:skipped] += 1
        next
      end
      if serial.blank? || part.blank? || qty <= 0
        stats[:errors] << "第#{i}行：六联单号/产品/数量缺失"
        stats[:skipped] += 1
        next
      end

      date = parse_date(val.call("日期"))
      tracking = val.call("快递号").to_s.strip
      group = groups[[serial, date, tracking]] ||= { qty_by_part: Hash.new(0), customers: [], rows: [] }
      group[:qty_by_part][part] += qty
      group[:customers] << val.call("客户")
      group[:rows] << i
    end
    groups
  end

  # 产品 → 六联单生产行（型号全名匹配 generic+suffix，同型号多行数量累加）
  def self.match_lines(so, group, serial, stats)
    line_qty = {}
    group[:qty_by_part].each do |part, qty|
      item = Item.where("generic_part_no || COALESCE(suffix, '') = :p", p: part).take
      pl = item && so.production_lines.find_by(item_id: item.id)
      unless pl
        stats[:errors] << "第#{group[:rows].first}行：产品「#{part}」在六联单「#{serial}」中没有对应行"
        next
      end
      line_qty[pl] = line_qty.fetch(pl, 0) + qty
    end
    line_qty
  end

  def self.open_spreadsheet(file)
    sheet = Roo::Excelx.new(file.path)
    sheet.default_sheet = sheet.sheets.include?("出库单") ? "出库单" : sheet.sheets.first
    sheet
  end

  def self.header_index(sheet)
    row = sheet.row(1)
    row.each_with_object({}).with_index do |(cell, m), i|
      h = cell.to_s.strip
      m[h] = i + 1 unless h.empty?
    end
  end

  def self.formatted(cell)
    cell.is_a?(Date) || cell.is_a?(Time) ? cell.to_date.to_s : cell.to_s
  end

  def self.parse_date(text)
    return text.to_date if text.is_a?(Date)
    return text.to_datetime.to_date if text.is_a?(Time)

    Date.strptime(text, "%Y-%m-%d")
  rescue ArgumentError, TypeError
    nil
  end
end
