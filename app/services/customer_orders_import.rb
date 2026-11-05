require "roo"

# 客户订单批量导入（第二阶段 2.2）：
# - 模板 = 月度工作簿「客户订单」表（接收日期/客户/订单号/通用型号/版本/数量/含税单价/要求交期/特殊要求/币别）
# - 按表头名称解析，忽略多余列
# - 订单号支持 -行号 后缀：多行订单写「PO123-1」「PO123-2」→ 归并为订单 PO123 的第 1/2 行；
#   单行订单直接写「PO123」。防误拆：同底号（PO123）全文件仅出现一次时不剥离（客户编号
#   本身可能以 -01 结尾）
# - 行合并键：同订单号+行号 → 同一行更新；不同行号或无行号按 通用型号+版本 区分
# - 价格匹配（D18 严格）：接收日期+客户+通用型号+含税单价 匹配报价（日期须在有效期内），
#   匹配不到 → 阻断报错（无跨客户兜底、无比例缩放）；多候选 → 警告取生效最新
# - 冲销行识别只认数量为负；价格继承原订单行快照（不重新匹配报价）
class CustomerOrdersImport
  HEADERS = %w[接收日期 客户 订单号 通用型号 版本 数量 含税单价 要求交期 特殊要求 币别].freeze

  def self.call(file, imported_by:, month: nil)
    sheet = open_spreadsheet(file)
    idx = header_index(sheet)
    raise "无法识别客户订单表头：缺少「订单号」列" if idx["订单号"].nil?

    stats = { created: 0, updated: 0, skipped: 0, errors: [], warnings: [] }

    # 预扫描：解析 订单号 的底号与行号；同底号出现两行及以上才认定 -数字 为行号并剥离
    # （防误拆：客户订单号本身可能以 -01 结尾，单行出现时整串保留）
    entries = []
    (2..sheet.last_row).each do |i|
      row = ->(name) { idx[name] ? formatted(sheet.cell(i, idx[name])) : "" }
      raw = row.call("订单号").to_s.strip
      generic = row.call("通用型号").to_s.strip
      next if raw.blank? && generic.blank?
      m = raw.match(/\A(.+)-(\d+)\z/)
      base = m ? m[1] : raw
      ln = m ? m[2].to_i : nil
      entries << { row_no: i, row: row, raw: raw, base: base, ln: ln,
                   generic: generic, skip_blank: raw.blank? || generic.blank? }
    end
    base_counts = entries.group_by { |e| e[:base] }.transform_values(&:size)

    entries.each do |e|
      i = e[:row_no]
      row = e[:row]
      po = e[:base]
      e_ln = e[:ln]
      has_ln = e_ln.present?
      multi = base_counts[e[:base]] >= 2
      raw = e[:raw]
      generic = e[:generic]
      if e[:skip_blank]
        stats[:errors] << "第#{i}行：订单号/通用型号缺失"
        stats[:skipped] += 1
        next
      end

      customer = Customer.find_by(name_zh: row.call("客户").to_s.strip) ||
                 Customer.find_by(name: row.call("客户").to_s.strip)
      unless customer
        stats[:errors] << "第#{i}行：找不到客户「#{row.call('客户')}」"
        stats[:skipped] += 1
        next
      end

      version = row.call("版本").to_s.strip.presence
      qty = row.call("数量").to_i
      recv_date = parse_date(row.call("接收日期"))
      total = parse_number(row.call("含税单价"))
      # 冲销行识别（D18）：只认数量为负（标注列不再参与识别）；冲销行价格自原行复制，免填含税单价
      return_line = qty.negative?
      missing = []
      missing << "接收日期" if recv_date.nil?
      missing << "数量" if qty.zero?
      missing << "含税单价" if total.nil? && !return_line
      unless missing.empty?
        stats[:errors] << "第#{i}行：缺少必填字段：#{missing.join('、')}"
        stats[:skipped] += 1
        next
      end

      # 型号严格校验（命名规则仅针对 Baseband）：位次不符/后缀非法 → 报错；
      # 派生出的通用型号必须在产品列表建档，否则报错阻断（冲销/正常行共用）
      raw_part = generic # 客户所订原文（完整型号或缺省）
      naming_err = Item.naming_error(raw_part)
      generic, = Item.parse_full_part_no(raw_part)
      if naming_err
        stats[:errors] << "第#{i}行：型号「#{raw_part}」#{naming_err}"
        stats[:skipped] += 1
        next
      end
      resolved = Item.find_by(generic_part_no: generic) || Item.find_by_any_part_no(raw_part)
      unless resolved
        stats[:errors] << "第#{i}行：型号「#{raw_part}」（通用型号 #{generic}）未建档，请先在产品列表维护"
        stats[:skipped] += 1
        next
      end
      generic = resolved.generic_part_no # 归一化（非 Baseband 类别通用型号 = 完整型号）

      if return_line
        import_return(stats, po: po, generic: generic, version: version,
                      abs_qty: qty.abs, row_no: i, remark: row.call("特殊要求").to_s,
                      recv_date: recv_date)
        next
      end

      # D18 严格价格匹配（单头落库前）：客户+通用型号+接收日期在有效期内+含税单价一致；
      # 匹配不到 → 阻断该行（无跨客户兜底、无比例缩放）
      as_of = recv_date || month || Date.current
      price = match_strict_price(customer, generic, as_of, total, qty, i, stats)
      next if price.nil?

      order = Order.find_or_initialize_by(po_number: po)
      if order.new_record?
        order = Order.build_with_customer(customer, po_number: po)
        order.currency = row.call("币别").to_s.strip.presence || order.currency
        order.created_at = recv_date if recv_date # 接收日期落库（列表/关账按此口径）
        order.snapshot_exchange_rate!
        order.status = "submitted"
        order.save!
        stats[:created] += 1
      elsif recv_date && order.created_at.to_date != recv_date
        order.update!(created_at: recv_date) # 重新导入：以文件的接收日期为准
      end

      line = if multi && has_ln
               order.order_lines.find_by(line_no: e_ln)
             else
               order.order_lines.find_by(generic_part_no: generic, version: version)
             end
      created_line = line.nil?
      line ||= order.order_lines.build(generic_part_no: generic, version: version.presence)
      line.line_no = e_ln if multi && has_ln && line.line_no.nil?
      line.full_part_no = e[:generic].presence || line.full_part_no # 客户所订型号原文（完整或通用）
      line.quantity = row.call("数量").to_i.nonzero? || line.quantity
      line.required_delivery_date = parse_date(row.call("要求交期")) || line.required_delivery_date
      line.remark = row.call("特殊要求").to_s.presence || line.remark
      # D14/D18：每次导入按 Excel 重新严格匹配并快照（匹配保证单价一致，直接复制报价成分，无缩放）
      line.assign_attributes(base_price: price.base_price, v1_price: price.v1_price,
                             v2_price: price.v2_price, price_id: price.id)
      line.save!
      created_line ? stats[:created] += 1 : stats[:updated] += 1
    rescue StandardError => e
      stats[:errors] << "第#{i}行：#{e.message}"
      stats[:skipped] += 1
    end

    Import.create!(kind: "customer_orders", month: month, filename: file.original_filename,
                    imported_by: imported_by, stats: stats)
  end

  # D18 严格价格匹配：客户 + 通用型号 + 接收日期落在有效期内 + 含税单价一致（容差 0.01）。
  # - 无候选 → 记 error（阻断，调用方 skip 该行）：无跨客户兜底、无比例缩放
  # - 档位选取与 match_for 同口径：订单量 ≤ 档位的最高档；低于最小档取最低档（MOQ）；
  #   并列取生效日期最新
  # - 歧义（同档位还有其他同价候选，如换批重报）→ 警告人工复核
  def self.match_strict_price(customer, generic, as_of, total, qty, row_no, stats)
    scope = Price.where(part_number: generic, status: %w[approved active], customer_id: customer.id)
                 .where("effective_from IS NULL OR effective_from <= ?", as_of)
                 .where("expired_at IS NULL OR expired_at >= ?", as_of)
    cands = scope.select { |p| (p.price.to_d - total.to_d).abs <= 0.01 }
    if cands.empty?
      stats[:errors] << "第#{row_no}行：#{generic} 单价 #{total}（接收日期 #{as_of}）无匹配报价" \
                        "（客户+型号+有效期+单价须一致），未导入"
      stats[:skipped] += 1
      return nil
    end

    tiers = cands.filter_map { |p| [Price.numeric_condition(p), p] }
    if tiers.empty?
      # 档位不可比（"1K" 等写法）：取生效日期最新
      chosen = cands.max_by { |p| [p.effective_from || Date.new(0), p.id] }
    else
      # 档位选取与 match_for 同口径：订单量 ≤ 档位的最高档；低于最小档取最低档（MOQ）；
      # 同档并列（如换批重报）取生效日期最新
      eligible = tiers.select { |c, _| c <= qty.to_f }
      c_pick = eligible.any? ? eligible.transpose.first.max : tiers.transpose.first.min
      chosen = tiers.select { |c, _| c == c_pick }
                    .max_by { |_, p| [p.effective_from || Date.new(0), p.id] }.last
    end

    if cands.any? { |p| p.id != chosen.id && p.condition == chosen.condition }
      stats[:warnings] << "第#{row_no}行：#{generic} 单价 #{total} 匹配到多条同价报价" \
                          "（#{cands.map(&:price_number).join('、')}），已取生效最新 #{chosen.price_number}，请人工复核"
    end
    chosen
  end

  # 冲销行：原订单 + 原行（通用型号+版本）→ kind=return 的冲销单「原PO-Rn」，
  # 行数量为负、引用原行、复制原行价格成分；冲销单头 created_at = 文件接收日期（列表/关账同口径）；
  # 重复导入幂等（更新同一冲销行，接收日期以文件为准刷新）
  def self.import_return(stats, po:, generic:, version:, abs_qty:, row_no:, remark:, recv_date:)
    original = Order.find_by(po_number: po)
    if original.nil? || original.return?
      stats[:errors] << "第#{row_no}行：冲销原订单「#{po}」不存在"
      stats[:skipped] += 1
      return
    end
    orig_line = original.order_lines.find_by(generic_part_no: generic, version: version) ||
                original.order_lines.find_by(generic_part_no: generic)
    if orig_line.nil?
      stats[:errors] << "第#{row_no}行：原订单「#{po}」没有「#{generic}」行，无法冲销"
      stats[:skipped] += 1
      return
    end

    ret_line = OrderLine.joins(:order).where(orders: { kind: "return" })
                        .find_by(refer_order_line_id: orig_line.id, generic_part_no: generic)
    if ret_line
      ret_line.quantity = -abs_qty
      ret_line.save!
      ret_order = ret_line.order
      if recv_date && ret_order.created_at.to_date != recv_date
        ret_order.update!(created_at: recv_date) # 重导：以文件的接收日期为准
      end
      stats[:updated] += 1
    else
      ret_order = Order.where(kind: "return").where("po_number LIKE ?", "#{po}-%")
                       .order(:po_number).first || create_return_order(original, recv_date)
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
    stats[:errors] << "第#{row_no}行：冲销「#{generic}」失败：#{e.message}"
    stats[:skipped] += 1
  end

  # 冲销单头：PO = 原单号-Rn（取空闲 n）；头信息快照自原单；created_at = 文件接收日期
  def self.create_return_order(original, recv_date = nil)
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
    order.created_at = recv_date if recv_date # 接收日期落库（与正常单同口径）
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
