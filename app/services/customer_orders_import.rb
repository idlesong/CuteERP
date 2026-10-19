require "roo"

# 客户订单批量导入（第二阶段 2.2）：
# - 模板 = 月度工作簿「客户订单」表（接收日期/客户/订单号/通用型号/版本/数量/含税单价/要求交期/特殊要求/币别）
# - 按表头名称解析，忽略多余列；自然键 = 订单号 + 通用型号 + 版本，重复导入幂等（只更新不重建）
# - 含税单价自动匹配报价拆分成分（Price.match_for）
# - 冲销行：数量为负（或类型/特殊要求标注冲销/核销）→ 生成 kind=return 冲销单「原PO-Rn」
class CustomerOrdersImport
  HEADERS = %w[接收日期 客户 订单号 通用型号 版本 数量 含税单价 要求交期 特殊要求 币别].freeze

  def self.call(file, imported_by:, month: nil)
    sheet = open_spreadsheet(file)
    idx = header_index(sheet)
    raise "无法识别客户订单表头：缺少「订单号」列" if idx["订单号"].nil?

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

      version = row.call("版本").to_s.strip.presence
      qty = row.call("数量").to_i
      # 冲销行：数量为负，或 类型/特殊要求 标注 冲销/核销/return
      marked = row.call("特殊要求").to_s.match?(/冲销|核销/) ||
               row.call("类型").to_s.match?(/冲销|核销|return/i)
      if qty.negative? || marked
        if qty.zero?
          stats[:warnings] << "第#{i}行：冲销行数量为空，跳过"
          stats[:skipped] += 1
          next
        end
        import_return(stats, po: po, generic: generic, version: version,
                      abs_qty: qty.abs, row_no: i, remark: row.call("特殊要求").to_s)
        next
      end

      order = Order.find_or_initialize_by(po_number: po)
      if order.new_record?
        order = Order.build_with_customer(customer, po_number: po)
        order.currency = row.call("币别").to_s.strip.presence || order.currency
        order.snapshot_exchange_rate!
        order.status = "submitted"
        order.save!
        stats[:created] += 1
      end

      line = order.order_lines.find_by(generic_part_no: generic, version: version)
      created_line = line.nil?
      line ||= order.order_lines.build(generic_part_no: generic, version: version.presence)
      line.quantity = row.call("数量").to_i.nonzero? || line.quantity
      total = parse_number(row.call("含税单价"))
      was_base = line.base_price
      # 成分从未拆分过（v1/v2 均空，含旧版导入塞在芯片列的总额）→ 清空后重新匹配，允许自愈
      if line.v1_price.blank? && line.v2_price.blank?
        line.base_price = nil
        line.price_id = nil
      end
      line.required_delivery_date = parse_date(row.call("要求交期")) || line.required_delivery_date
      line.remark = row.call("特殊要求").to_s.presence || line.remark
      # 有效期以接收日期为基准（补录历史订单也能命中当时有效的报价）
      as_of = parse_date(row.call("接收日期")) || month || Date.current
      OrderLine.apply_price_snapshot(line, total: total, date: as_of)

      if line.price_id.present?
        matched = Price.find(line.price_id)
        if matched.customer_id != order.customer_id
          stats[:warnings] << "第#{i}行：#{generic} 无本客户报价，暂用客户「#{matched.customer_name}」的报价 #{matched.price_number}，请人工确认"
        elsif total && (total.to_d - matched.price.to_d).abs > 0.01
          stats[:warnings] << "第#{i}行：订单单价 #{total} ≠ 报价 #{matched.price}（#{matched.price_number}），已按报价比例拆分，请人工复核"
        end
      else
        line.base_price = total || was_base if line.base_price.nil? # 无报价：维持原口径（全额计入芯片）
        stats[:warnings] << "第#{i}行：#{generic} 未匹配到可用报价，成分未拆分" if total
      end
      line.save!
      created_line ? stats[:created] += 1 : stats[:updated] += 1
    rescue StandardError => e
      stats[:warnings] << "第#{i}行：#{e.message}"
      stats[:skipped] += 1
    end

    Import.create!(kind: "customer_orders", month: month, filename: file.original_filename,
                    imported_by: imported_by, stats: stats)
  end

  # 冲销行：原订单 + 原行（通用型号+版本）→ kind=return 的冲销单「原PO-Rn」，
  # 行数量为负、引用原行、复制原行价格成分；重复导入幂等（更新同一冲销行）
  def self.import_return(stats, po:, generic:, version:, abs_qty:, row_no:, remark:)
    original = Order.find_by(po_number: po)
    if original.nil? || original.return?
      stats[:warnings] << "第#{row_no}行：冲销原订单「#{po}」不存在，跳过"
      stats[:skipped] += 1
      return
    end
    orig_line = original.order_lines.find_by(generic_part_no: generic, version: version) ||
                original.order_lines.find_by(generic_part_no: generic)
    if orig_line.nil?
      stats[:warnings] << "第#{row_no}行：原订单「#{po}」没有「#{generic}」行，无法冲销，跳过"
      stats[:skipped] += 1
      return
    end

    ret_line = OrderLine.joins(:order).where(orders: { kind: "return" })
                        .find_by(refer_order_line_id: orig_line.id, generic_part_no: generic)
    if ret_line
      ret_line.quantity = -abs_qty
      ret_line.save!
      stats[:updated] += 1
    else
      ret_order = Order.where(kind: "return").where("po_number LIKE ?", "#{po}-%")
                       .order(:po_number).first || create_return_order(original)
      ret_order.order_lines.create!(
        generic_part_no: generic, version: version, quantity: -abs_qty,
        refer_order_line_id: orig_line.id,
        base_price: orig_line.base_price, v1_price: orig_line.v1_price,
        v2_price: orig_line.v2_price, price_id: orig_line.price_id,
        remark: remark.presence || "冲销 #{orig_line.display_no}"
      )
      stats[:created] += 1
    end
  rescue ActiveRecord::RecordInvalid => e
    stats[:warnings] << "第#{row_no}行：冲销「#{generic}」失败：#{e.message}"
    stats[:skipped] += 1
  end

  # 冲销单头：PO = 原单号-Rn（取空闲 n）；头信息快照自原单
  def self.create_return_order(original)
    taken = Order.where("po_number LIKE ?", "#{original.po_number}-%").pluck(:po_number)
    n = 1
    n += 1 while taken.include?("#{original.po_number}-R#{n}")

    order = Order.build_with_customer(original.customer, po_number: "#{original.po_number}-R#{n}")
    order.assign_attributes(original.slice(:name, :address, :telephone, :ship_contact,
                                           :ship_address, :ship_telephone, :pay_type,
                                           :currency, :exchange_rate))
    order.kind = "return"
    order.end_customer_id = original.end_customer_id
    order.status = "submitted"
    order.save!
    order
  end

  def self.open_spreadsheet(file)
    sheet = Roo::Excelx.new(file.path)
    # 缺「客户订单」表时退回第一张表（容忍用户改表名）
    sheet.default_sheet = sheet.sheets.include?("客户订单") ? "客户订单" : sheet.sheets.first
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
