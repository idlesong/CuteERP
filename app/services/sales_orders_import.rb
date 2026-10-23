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
    stats = { created: 0, updated: 0, skipped: 0, errors: [], warnings: [] }

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
        stats[:errors] << "第#{i}行：找不到客户「#{val.call('客户')}」"
        stats[:skipped] += 1
        next
      end

      generic, part_suffix = Item.parse_full_part_no(part)
      item = Item.find_by(generic_part_no: generic) || Item.find_by_any_part_no(part)
      unless item
        stats[:errors] << "第#{i}行：产品「#{part}」未建档"
        stats[:skipped] += 1
        next
      end

      so = SalesOrder.find_or_initialize_by(serial_number: serial)
      created_order = so.new_record?
      if created_order
        so.initialize_order_header(customer)
        so.snapshot_exchange_rate!
        so.status = "submitted" # D14：Excel 为准直接入台账（draft 的分配不计入订单已分配）
        so.created_at = parse_date(val.call("下单日期")) if val.call("下单日期").present?
      end

      qty = val.call("数量").to_i
      part_suffix = part_suffix.presence || item.suffix.presence
      line = so.production_lines.find_by(item_id: item.id, suffix: part_suffix)
      created_line = line.nil?
      line ||= so.production_lines.build(item: item, suffix: part_suffix, source: "batch")
      if line.shipped_qty.positive? && line.quantity < line.shipped_qty
        stats[:errors] << "第#{i}行：#{serial} #{part} 数量低于已出库（#{line.shipped_qty}）"
        stats[:skipped] += 1
        next
      end
      line.quantity = qty if qty.positive?
      line.version = val.call("版本").to_s.presence || line.version
      line.full_name ||= part
      # 头+行一次落库：新建时 production_lines 必填（on: :create），先建头会验证失败
      so.save!
      stats[:created] += 1 if created_order

      if so.required_date.blank? && val.call("约定发货日期").present?
        so.update_columns(required_date: parse_date(val.call("约定发货日期")))
      end

      rebuild_allocations(line, pair_cols, sheet, i, val, stats)
      created_line ? stats[:created] += 1 : stats[:updated] += 1
    rescue StandardError => e
      stats[:errors] << "第#{i}行：#{e.message}"
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
      targets = allocation_targets(display, line, qty)
      if targets.empty?
        stats[:errors] << "第#{row_no}行：分配引用「#{display}」无法解析（未建档/行号不存在/多行同型号请写 订单号-行号）"
        next
      end
      targets.each do |target, qty|
        sums[target] = sums.fetch(target, 0) + qty
      end
    end

    line.production_allocations.destroy_all
    sums.each do |target, qty|
      balance = target.allocatable_qty
      if qty > balance
        stats[:errors] << "第#{row_no}行：分配 #{target.display_no} x#{qty} 超过未签发余额（#{balance}）"
        qty = [balance, 0].max
      end
      line.production_allocations.create!(order_line: target, quantity: qty) if qty.positive?
    end

    sum_alloc = line.reload.production_allocations.sum(:quantity)
    if sum_alloc != line.quantity
      stats[:errors] << "第#{row_no}行：Σ分配量（#{sum_alloc}）≠ 六联单数量（#{line.quantity}）"
    end
  end

  # 分配引用解析，兼容三种写法：
  # 1) 订单号-行号（如 AB2026-003-1，系统行编号）——精确一行
  # 2) 纯订单号且订单仅一行 —— 该行
  # 3) 纯订单号且多行 —— 该订单该产品的行按行号 FIFO 分配（前面行余额不足自动溢到后续行）
  # 返回 [[order_line, qty], ...]；无法解析返回 []（由调用方报错）
  def self.allocation_targets(display, prod_line, qty)
    po, _, ln = display.rpartition("-")
    if ln.match?(/\A\d+\z/)
      exact = OrderLine.joins(:order).find_by(orders: { po_number: po }, line_no: ln.to_i)
      return exact ? [[exact, qty]] : []
    end

    lines = OrderLine.joins(:order).where(orders: { po_number: display }).order(:line_no)
    return [] if lines.empty?

    # 优先该六联单产品对应的行；无对应行则视为全部行都可分配
    generic = prod_line.item&.generic_part_no
    matched = generic ? lines.where(generic_part_no: [generic, prod_line.item.partNo]) : lines.none
    lines = matched.presence || lines

    out = []
    left = qty
    lines.each do |ol|
      break if left <= 0
      take = [ol.allocatable_qty, left].min
      if take.positive?
        out << [ol, take]
        left -= take
      end
    end
    out
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
