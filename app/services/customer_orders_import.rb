require "roo"

# 客户订单批量导入（第二阶段 2.2）：
# - 模板 = 月度工作簿「客户订单」表（接收日期/客户/订单号/通用型号/版本/数量/含税单价/要求交期/特殊要求/币别）
# - 自然键 = 订单号 + 通用型号 + 版本，重复导入幂等（只更新不重建）
class CustomerOrdersImport
  HEADERS = %w[接收日期 客户 订单号 通用型号 版本 数量 含税单价 要求交期 特殊要求 币别].freeze

  def self.call(file, imported_by:, month: nil)
    sheet = open_spreadsheet(file)
    idx = header_index(sheet)

    stats = { created: 0, updated: 0, skipped: 0, warnings: [] }
    (2..sheet.last_row).each do |i|
      row = ->(name) { idx[name] ? formatted(sheet.cell(i, idx[name])) : "" }
      po = row.call("订单号").to_s.strip
      generic = row.call("通用型号").to_s.strip
      if po.blank? && generic.blank?
        stats[:skipped] += 1
        next
      end
      if po.blank? || generic.blank?
        stats[:warnings] << "第#{i}行：订单号/通用型号缺失，跳过"
        stats[:skipped] += 1
        next
      end

      customer = Customer.find_by(name_zh: row.call("客户").to_s.strip) ||
                 Customer.find_by(name: row.call("客户").to_s.strip)
      unless customer
        stats[:warnings] << "第#{i}行：找不到客户「#{row.call('客户')}」，跳过"
        stats[:skipped] += 1
        next
      end

      order = Order.find_or_initialize_by(po_number: po)
      if order.new_record?
        order = Order.build_with_customer(customer, po_number: po)
        order.snapshot_exchange_rate!
        order.status = "submitted"
        order.save!
        stats[:created] += 1
      end

      version = row.call("版本").to_s.strip.presence
      line = order.order_lines.find_by(generic_part_no: generic, version: version)
      created_line = line.nil?
      line ||= order.order_lines.build(generic_part_no: generic, version: version.presence)
      line.quantity = row.call("数量").to_i.nonzero? || line.quantity
      line.base_price = parse_number(row.call("含税单价")) || line.base_price
      line.required_delivery_date = parse_date(row.call("要求交期")) || line.required_delivery_date
      line.remark = row.call("特殊要求").to_s.presence || line.remark
      line.save!
      created_line ? stats[:created] += 1 : stats[:updated] += 1
    rescue StandardError => e
      stats[:warnings] << "第#{i}行：#{e.message}"
      stats[:skipped] += 1
    end

    Import.create!(kind: "customer_orders", month: month, filename: file.original_filename,
                    imported_by: imported_by, stats: stats)
  end

  def self.open_spreadsheet(file)
    sheet = Roo::Excelx.new(file.path)
    sheet.default_sheet = "客户订单"
    sheet
  end

  def self.header_index(sheet)
    row = sheet.row(1)
    HEADERS.index_by { |h| h } # 校验用
    HEADERS.each_with_object({}) do |h, m|
      col = row.index(h)
      m[h] = col + 1 if col
    end
  end

  def self.formatted(cell)
    cell.is_a?(Date) || cell.is_a?(Time) ? cell.to_date.to_s : cell.to_s
  end

  def self.parse_number(text)
    t = text.to_s.gsub(/[,%，¥$ ]/, "")
    t.match?(/\A\d+(\.\d+)?\z/) ? t.to_f : nil
  end

  def self.parse_date(text)
    return text.to_date if text.is_a?(Date)
    return text.to_datetime.to_date if text.is_a?(Time)

    Date.strptime(text, "%Y-%m-%d")
  rescue ArgumentError, TypeError
    nil
  end
end
