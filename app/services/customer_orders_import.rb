require "roo"

# 客户订单批量导入（第二阶段 2.2）：
# - 模板 = 月度工作簿「客户订单」表（接收日期/客户/订单号/通用型号/版本/数量/含税单价/要求交期/特殊要求/币别）
# - 按表头名称解析，忽略多余列
# - 订单号支持 -行号 后缀：多行订单写「PO123-1」「PO123-2」→ 归并为订单 PO123 的第 1/2 行；
#   单行订单直接写「PO123」。防误拆：同底号（PO123）全文件仅出现一次时不剥离（客户编号
#   本身可能以 -01 结尾）
# - 行合并键：同订单号+行号 → 同一行更新；不同行号或无行号按 通用型号+版本 区分
# - 价格匹配（参考价语义）：客户+通用型号+接收日期（在报价有效期内）匹配正式报价；
#   Excel 单价仅辅助收敛（同档选最接近者），不作为一致性与否的判据；
#   匹配不到 → 阻断报错（无跨客户兜底）；多候选 → 警告
# - 冲销行识别只认数量为负；价格继承原订单行快照（不重新匹配报价）
class CustomerOrdersImport
  HEADERS = %w[接收日期 客户 订单号 通用型号 版本 数量 含税单价 要求交期 特殊要求 币别].freeze

  def self.call(file, imported_by:, month: nil)
    sheet = open_spreadsheet(file)
    idx = header_index(sheet)
    raise "无法识别客户订单表头：缺少「订单号」列" if idx["订单号"].nil?

    stats = { created: 0, updated: 0, skipped: 0, errors: [], warnings: [] }
    # 汇总校验（control totals）累计器：Excel 有效行 vs 实际导入行 / 数量合计
    # ——行级校验抓显式错误，行数+数量合计抓「静默覆盖/丢失」（金额不校验：参考价语义）
    ok_rows = 0
    ex_qty = sys_qty = 0

    # 预扫描：解析 订单号 的底号与行号。行号识别（最终规则）：
    # 仅「# + 一位数字」尾缀视为 行号 写法（如 PO123#1、PO123#2 → 归并订单 PO123 行 1/2）；
    # 其余一律不合并（-01/-02/-1、_2、长尾客户编号 DYA421-20260113301、ACKPO-260325-02 等
    # 整串为订单号）
    entries = []
    (2..sheet.last_row).each do |i|
      row = ->(name) { idx[name] ? formatted(sheet.cell(i, idx[name])) : "" }
      raw = row.call("订单号").to_s.strip
      generic = row.call("通用型号").to_s.strip
      next if raw.blank? && generic.blank?
      m = raw.match(/\A(.+)#(\d)\z/)
      base = m ? m[1] : raw
      ln = m ? m[2].to_i : nil
      entries << { row_no: i, row: row, raw: raw, base: base, ln: ln,
                   qty: row.call("数量").to_i,
                   generic: generic, skip_blank: raw.blank? || generic.blank? }
    end
    base_counts = entries.group_by { |e| e[:base] }.transform_values(&:size)

    # 单行底号不剥离：该底号全文件仅出现一次时整串保留为订单号
    # （现规则仅 #行号 归并，非 # 尾缀天然不拆；显式还原以保持防御性）
    entries.each do |e|
      multi = base_counts[e[:base]] >= 2
      e[:multi] = multi
      next if multi

      e[:base] = e[:raw]
      e[:ln] = nil
    end

    # 组内行号计划（仅作用于正行）：显式 #行号 占位；未写行号的正行按 Excel 序补最小空号。
    # 核销行（数量<0）不参与计划——其 #序号 是核销单内的核销序，与正订单行号空间独立
    # （场景：正行 PO1 + 核销 PO1#1/#2 → 正行仍为行1，核销单 R1 两行 1/-20、2/-30）
    line_plan = {}
    entries.reject { |e| e[:skip_blank] }.group_by { |e| e[:base] }.each do |_, group|
      pos = group.select { |e| e[:qty] >= 0 }
      next unless pos.size >= 2

      used = pos.filter_map { |e| e[:ln] }
      pos.each do |e|
        next if e[:ln]

        n = (1..).find { |k| !used.include?(k) }
        line_plan[e[:row_no]] = n
        used << n
      end
    end

    entries.each do |e|
      i = e[:row_no]
      row = e[:row]
      po = e[:base]
      e_ln = e[:ln]
      multi = e[:multi]
      planned_ln = line_plan[i] # 组内补位行号（未写行号的行）
      target_ln = e_ln || planned_ln
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
        ret = import_return(stats, po: po, generic: generic, version: version,
                            abs_qty: qty.abs, row_no: i, remark: row.call("特殊要求").to_s,
                            recv_date: recv_date, ln: e_ln)
        if ret[:status] # 核销成功：计入汇总（数量口径；金额不校验）
          ok_rows += 1
          ex_qty += qty
          sys_qty += ret[:qty_delta]
        end
        next
      end

      # 正式价格匹配（参考价语义）：客户+通用型号+接收日期在有效期内，Excel 单价仅辅助收敛；
      # 匹配不到 → 阻断该行（无跨客户兜底）
      as_of = recv_date || month || Date.current
      price = match_formal_price(customer, generic, as_of, total, qty, i, stats, po: po)
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

      line = if multi && target_ln
               order.order_lines.find_by(line_no: target_ln)
             else
               order.order_lines.find_by(generic_part_no: generic, version: version)
             end
      created_line = line.nil?
      line ||= order.order_lines.build(generic_part_no: generic, version: version.presence)
      line.line_no = target_ln if multi && target_ln && line.line_no.nil?
      line.full_part_no = e[:generic].presence || line.full_part_no # 客户所订型号原文（完整或通用）
      line.quantity = row.call("数量").to_i.nonzero? || line.quantity
      line.required_delivery_date = parse_date(row.call("要求交期")) || line.required_delivery_date
      line.remark = row.call("特殊要求").to_s.presence || line.remark
      # 参考价语义：订单正式价格 = 匹配到的报价总价/成分（价格表权威，覆盖 Excel 参考单价）
      line.assign_attributes(base_price: price.base_price, v1_price: price.v1_price,
                             v2_price: price.v2_price, price_id: price.id)
      line.save!
      created_line ? stats[:created] += 1 : stats[:updated] += 1
      # 汇总累计（行成功后）：口径 = 处理后这些行的最终值合计（正行 line.quantity / 核销 -abs）
      # ——与 Excel 侧 Σ 相等则一致；覆盖丢行/静默丢失时两侧必不等
      ok_rows += 1
      ex_qty += qty
      sys_qty += line.quantity

    rescue StandardError => e
      stats[:errors] << "第#{i}行：#{e.message}"
      stats[:skipped] += 1
    end

    stats[:control] = { excel_rows: entries.count { |e| !e[:skip_blank] }, rows: ok_rows,
                        excel_qty: ex_qty, qty: sys_qty } # 金额合计不校验（参考价语义：Excel 金额为粗略参考）
    Import.create!(kind: "customer_orders", month: month, filename: file.original_filename,
                    imported_by: imported_by, stats: stats)
  end

  # 正式价格匹配（参考价语义，替代 D18 严格匹配）：
  # 匹配键 = 客户 + 通用型号 + 接收日期落在有效期内；**Excel 单价仅辅助收敛，不作为一致性与否的判据**。
  # - 无候选 → 记 error（阻断，调用方 skip 该行）：无跨客户兜底
  # - 档位选取与 match_for 同口径：订单量 ≤ 档位的最高档；低于最小档取最低档（MOQ）
  # - 同档多条候选：选「与 Excel 参考单价最接近」的报价（参考价辅助定位），并列取生效日期最新
  # - 订单行正式价格 = 匹配报价的总价/成分（价格表权威；Excel 单价差异仅提示不阻断）
  def self.match_formal_price(customer, generic, as_of, total, qty, row_no, stats, po: nil)
    scope = Price.where(part_number: generic, status: %w[approved active], customer_id: customer.id)
                 .where("effective_from IS NULL OR effective_from <= ?", as_of)
                 .where("expired_at IS NULL OR expired_at >= ?", as_of)
    cands = scope.to_a
    if cands.empty?
      stats[:errors] << "第#{row_no}行：#{po} #{generic}（接收日期 #{as_of}）无可用报价" \
                        "（客户+型号+有效期须命中），未导入"
      stats[:skipped] += 1
      return nil
    end

    tiers = cands.filter_map { |p| [Price.numeric_condition(p), p] }
    if tiers.empty?
      # 档位不可比（"1K" 等写法）：取生效日期最新
      chosen = cands.max_by { |p| [p.effective_from || Date.new(0), p.id] }
    elsif total
      # 参考价语义：Excel 参考单价定位正式报价档——选「档位报价与参考单价最接近」的档位，
      # 同档并列取生效日期最新
      c_pick = tiers.min_by { |_, p| (p.price.to_d - total.to_d).abs }.first
      pool = tiers.select { |c, _| c == c_pick }
      chosen = pool.max_by { |_, p| [p.effective_from || Date.new(0), p.id] }.last
    else
      # 无参考单价（核销等）：数量档位（≤ 最高档 / MOQ 最低档）+ 同档并列取生效日期最新（match_for 口径）
      eligible = tiers.select { |c, _| c <= qty.to_f }
      c_pick = eligible.any? ? eligible.transpose.first.max : tiers.transpose.first.min
      tiers.select { |c, _| c == c_pick }
           .max_by { |_, p| [p.effective_from || Date.new(0), p.id] }.last
    end

    if total && (chosen.price.to_d - total.to_d).abs > 0.01
      stats[:warnings] << "第#{row_no}行：#{generic} 订单按报价 #{chosen.price}（#{chosen.price_number}）计价，" \
                          "Excel 参考单价 #{total} 未采用，请人工复核"
    end
    if cands.any? { |p| p.id != chosen.id && p.condition == chosen.condition }
      stats[:warnings] << "第#{row_no}行：#{generic} 同档位匹配到多条报价" \
                          "（#{cands.map(&:price_number).join('、')}），已取与参考单价最接近的 #{chosen.price_number}，请人工复核"
    end
    chosen
  end

  # 冲销行：原订单 + 原行（通用型号+版本）→ kind=return 的冲销单「原PO-Rn」，
  # 行数量为负、引用原行、复制原行价格成分；冲销单头 created_at = 文件接收日期（列表/关账同口径）。
  # 核销单序（#序号）：核销行订单号写 原PO#N → 目标冲销单 = 原PO-RN（各自独立的核销单/接收日期，
  # 同 # 重导幂等更新；不同 # 各自独立，日期互不覆盖）；不写 # 视为单笔核销（归并到该 PO 的
  # 第一张核销单，重导覆盖更新，兼容存量）。
  # 返回 { status: :created/:updated/nil, unit_price: }（status 供汇总校验判定成功；nil = 失败/跳过）
  def self.import_return(stats, po:, generic:, version:, abs_qty:, row_no:, remark:, recv_date:, ln: nil)
    original = Order.find_by(po_number: po)
    if original.nil? || original.return?
      stats[:errors] << "第#{row_no}行：冲销原订单「#{po}」不存在"
      stats[:skipped] += 1
      return { status: nil }
    end
    orig_line = original.order_lines.find_by(generic_part_no: generic, version: version) ||
                original.order_lines.find_by(generic_part_no: generic)
    if orig_line.nil?
      stats[:errors] << "第#{row_no}行：原订单「#{po}」没有「#{generic}」行，无法冲销"
      stats[:skipped] += 1
      return { status: nil }
    end

    # 目标核销单：#序号 给定 → 原PO-RN（各自独立的核销单/接收日期；不存在则建）；
    # 不写 # → 该 PO 的第一张核销单（单笔兼容，重导覆盖更新）
    ret_order = if ln
                  Order.find_by(po_number: "#{po}-R#{ln}", kind: "return") ||
                    create_return_order(original, recv_date, rn: ln)
                else
                  Order.where(kind: "return").where("po_number LIKE ?", "#{po}-%")
                       .order(:po_number).first || create_return_order(original, recv_date)
                end

    ret_line = ret_order.order_lines.find_by(refer_order_line_id: orig_line.id, generic_part_no: generic)
    if ret_line
      old_qty = ret_line.quantity
      ret_line.quantity = -abs_qty
      ret_line.save!
      if recv_date && ret_order.created_at.to_date != recv_date
        ret_order.update!(created_at: recv_date) # 重导：以文件的接收日期为准
      end
      stats[:updated] += 1
      { status: :updated, unit_price: orig_line.unit_price, qty_delta: -abs_qty - old_qty }
    else
      line = ret_order.order_lines.build(
        generic_part_no: generic, version: version, quantity: -abs_qty,
        refer_order_line_id: orig_line.id,
        base_price: orig_line.base_price, v1_price: orig_line.v1_price,
        v2_price: orig_line.v2_price, price_id: orig_line.price_id,
        remark: remark.presence || "冲销 #{orig_line.display_no}"
      )
      line.save!
      stats[:created] += 1
      { status: :created, unit_price: orig_line.unit_price, qty_delta: -abs_qty }
    end
  rescue ActiveRecord::RecordInvalid => e
    stats[:errors] << "第#{row_no}行：冲销「#{generic}」失败：#{e.message}"
    stats[:skipped] += 1
    { status: nil }
  end

  # 冲销单头：PO = 原单号-Rn（rn 给定用之；缺省取空闲 n）；头信息快照自原单；created_at = 文件接收日期
  def self.create_return_order(original, recv_date = nil, rn: nil)
    po_number = rn ? "#{original.po_number}-R#{rn}" : begin
      taken = Order.where("po_number LIKE ?", "#{original.po_number}-%").pluck(:po_number)
      n = 1
      n += 1 while taken.include?("#{original.po_number}-R#{n}")
      "#{original.po_number}-R#{n}"
    end

    order = Order.build_with_customer(original.customer, po_number: po_number)
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

    s = text.to_s.strip
    return Date.new(1899, 12, 30) + s.to_i if s.match?(/\A\d{5}\z/) # Excel 日期序数（单元格无日期格式时）

    Date.strptime(s, "%Y-%m-%d")
  rescue ArgumentError, TypeError
    begin
      Date.parse(s) # 宽松兜底：2026/8/1、2026-8-1 等斜杠/简写格式
    rescue StandardError
      nil
    end
  end
end
