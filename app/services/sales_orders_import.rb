require "roo"

# 生产订单（六联单）批量导入（第二阶段 2.2，D14：FIFO 分配结果以 Excel 为准，直接入台账）
# - 模板 = 月度工作簿「生产订单-六联单」表，含 订单N/分配量N 分配对列
# - 自然键 = 六联单号（serial_number）；行按正式型号匹配；分配按行重建（未出库部分）
# - 校验报告：Σ分配量 vs 数量、引用订单行存在、分配量 ≤ 未签发余额（只报告不自动修）
class SalesOrdersImport
  BASE_HEADERS = %w[六联单号 下单日期 客户 产品 数量 含税单价 版本 约定发货日期 发货数量].freeze

  def self.call(file, imported_by:, month: nil)
    sheet = open_spreadsheet(file)
    idx = header_index(sheet)
    pair_cols = allocation_pairs(idx)
    stats = { created: 0, updated: 0, skipped: 0, warnings: [] }

    (2..sheet.last_row).each do |i|
      val = ->(name) { idx[name] ? formatted(sheet.cell(i, idx[name])) : "" }
      serial = val.call("六联单号").to_s.strip
      part = val.call("产品").to_s.strip
      if serial.blank? || part.blank?
        stats[:skipped] += 1
        next
      end

      customer = Customer.find_by(name_zh: val.call("客户").to_s.strip) ||
                 Customer.find_by(name: val.call("客户").to_s.strip)
      unless customer
        stats[:warnings] << "第#{i}行：找不到客户「#{val.call('客户')}」，跳过"
        stats[:skipped] += 1
        next
      end

      item = Item.where("generic_part_no || COALESCE(suffix, '') = :part", part: part).take
      unless item
        stats[:warnings] << "第#{i}行：产品「#{part}」未建档，跳过"
        stats[:skipped] += 1
        next
      end

      so = SalesOrder.find_or_initialize_by(serial_number: serial)
      if so.new_record?
        so.initialize_order_header(customer)
        so.snapshot_exchange_rate!
        so.save!
        stats[:created] += 1
      end

      qty = val.call("数量").to_i
      line = so.production_lines.find_by(item_id: item.id)
      created_line = line.nil?
      line ||= so.production_lines.build(item: item, source: "batch")
      if line.shipped_qty.positive? && line.quantity < line.shipped_qty
        stats[:warnings] << "第#{i}行：#{serial} #{part} 数量低于已出库（#{line.shipped_qty}），保持原值"
        stats[:skipped] += 1
        next
      end
      line.quantity = qty if qty.positive?
      line.version = val.call("版本").to_s.presence || line.version
      line.full_name ||= part
      line.save!

      if so.required_date.blank? && val.call("约定发货日期").present?
        so.update_columns(required_date: parse_date(val.call("约定发货日期")))
      end

      rebuild_allocations(line, pair_cols, sheet, i, val, stats)
      created_line ? stats[:created] += 1 : stats[:updated] += 1
    rescue StandardError => e
      stats[:warnings] << "第#{i}行：#{e.message}"
      stats[:skipped] += 1
    end

    Import.create!(kind: "sales_orders", month: month, filename: file.original_filename,
                    imported_by: imported_by, stats: stats)
  end

  # 分配对列（订单N/分配量N）：整行分配按文件重建（D14 Excel 为准）；已出库行不动
  def self.rebuild_allocations(line, pair_cols, sheet, row_no, val, stats)
    return if line.shipped_qty.positive?

    pairs = []
    pair_cols.each do |(order_col, qty_col)|
      display = formatted(sheet.cell(row_no, order_col)).to_s.strip
      qty = sheet.cell(row_no, qty_col).to_i
      pairs << [display, qty] if display.present? && qty.positive?
    end

    sums = {}
    pairs.each do |display, qty|
      po, _, line_no = display.rpartition("-")
      target = OrderLine.joins(:order).find_by(orders: { po_number: po }, line_no: line_no.to_i)
      if target.nil?
        stats[:warnings] << "第#{row_no}行：分配引用的订单行「#{display}」不存在"
        next
      end
      sums[target] = sums.fetch(target, 0) + qty
    end

    line.production_allocations.destroy_all
    sums.each do |target, qty|
      balance = target.allocatable_qty
      if qty > balance
        stats[:warnings] << "第#{row_no}行：分配 #{target.display_no} x#{qty} 超过未签发余额（#{balance}），按余额封顶"
        qty = [balance, 0].max
      end
      line.production_allocations.create!(order_line: target, quantity: qty) if qty.positive?
    end

    sum_alloc = line.reload.production_allocations.sum(:quantity)
    if sum_alloc != line.quantity
      stats[:warnings] << "第#{row_no}行：Σ分配量（#{sum_alloc}）≠ 六联单数量（#{line.quantity}）"
    end
  end

  def self.allocation_pairs(idx)
    pairs = []
    idx.each do |h, col|
      if (m = h.match(/\A订单(\d+)\z/)) && idx["分配量#{m[1]}"]
        pairs << [col, idx["分配量#{m[1]}"]]
      end
    end
    pairs.sort_by(&:first)
  end

  def self.open_spreadsheet(file)
    sheet = Roo::Excelx.new(file.path)
    sheet.default_sheet = "生产订单-六联单"
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
