require "roo"
require "digest"

# 核对导入（phase3 3.2）：上传核对工作簿（ReconciliationWorkbook 导出格式）→
# 预览差异（不落库，Import status=preview）→ 人工确认 → 事务内应用（status=applied）
#
# - 区间自动检测（D22）：按文件内各表单据日期 min/max 整月对齐，与系统同区间对比
# - 指纹双层匹配（D16）：行ID 精确匹配优先；无指纹按键列（订单号+行号 / 六联单号+产品）；
#   行ID 命中但 updated_at 漂移 → 照常比对并警告
# - 差异分类：新增 / 修改（字段级 改前→改后）/ 删除（D15：已提交作废标记 [作废]+数量置 0，
#   草稿物理删）/ 冲突（关账月、已出库缩减、无匹配报价、产品未建档…）→ 阻断行不应用
# - sha256 防重复（D16）：同文件已 applied 的批次拒绝再次上传
# - 发货核对方向：Excel 补录 → 新增出库明细（source_key 幂等）；系统多录 → 仅提示人工处理
# - 未交订单核对为只读对照表，不参与导入
class ReconciliationImport
  SHEETS = %w[订单核对 销售订单核对 发货核对 未交订单核对].freeze
  VOID_MARK = "[作废]"

  class << self
    # ---- 预览：解析 + 差异计算 + 暂存（不落任何业务数据）----
    def check(file, imported_by:)
      sha = Digest::SHA256.file(file.path).hexdigest
      dup = Import.find_by(kind: "reconciliation", sha256: sha, status: "applied")
      raise "该文件已应用过（批次 ##{dup.id}，#{dup.created_at.strftime('%m-%d %H:%M')}），不能重复导入" if dup

      Import.create!(kind: "reconciliation", filename: file.original_filename,
                     imported_by: imported_by, sha256: sha, status: "preview",
                     stats: parse_and_diff(file))
    end

    # ---- 确认：事务内应用全部非阻断差异 ----
    def apply!(imp)
      raise "批次 ##{imp.id} 状态为 #{imp.status}，不能应用" unless imp.status == "preview"

      stats = imp.stats
      report = ActiveRecord::Base.transaction do
        {
          "orders" => apply_section(stats["orders"], :orders),
          "sales_orders" => apply_section(stats["sales_orders"], :sales_orders),
          "shipments" => apply_section(stats["shipments"], :shipments)
        }
      end
      imp.update!(status: "applied", stats: stats.merge("apply" => report))
      imp
    end

    # ---- 解析与差异计算 ----
    def parse_and_diff(file)
      sheet = Roo::Excelx.new(file.path)
      SHEETS.each do |name|
        unless sheet.sheets.include?(name)
          raise "缺「#{name}」表——请上传核对导出生成的工作簿"
        end

        sheet.default_sheet = name
        unless sheet.cell(1, 1) == "TEMPLATE_VERSION" &&
               sheet.cell(1, 2).to_i == ReconciliationWorkbook::TEMPLATE_VERSION
          raise "「#{name}」模板版本不匹配（应为 v#{ReconciliationWorkbook::TEMPLATE_VERSION}），请重新核对导出"
        end
      end

      range = detect_range(sheet)
      {
        "range" => { "from" => range.begin.to_date.to_s, "to" => range.end.to_date.to_s },
        "orders" => diff_orders(sheet, range),
        "sales_orders" => diff_sales_orders(sheet, range),
        "shipments" => diff_shipments(sheet, range),
        "backlog" => { "note" => "未交订单核对为只读对照表，不参与导入" }
      }
    end

    private

    def parse_date(cell)
      return cell.to_date if cell.is_a?(Date)
      return cell.to_datetime.to_date if cell.is_a?(Time)

      Date.strptime(cell.to_s.strip, "%Y-%m-%d")
    rescue ArgumentError, TypeError
      nil
    end

    def text(cell) = cell.to_s.strip

    # 区间检测（D22）：三表单据日期 min/max，整月对齐
    def detect_range(sheet)
      dates = []
      SHEETS.first(3).each do |name|
        sheet.default_sheet = name
        (3..sheet.last_row).each do |i|
          d = parse_date(sheet.cell(i, 1))
          dates << d if d
        end
      end
      raise "工作簿内无单据日期，无法确定核对区间" if dates.empty?

      dates.min.beginning_of_month.beginning_of_day..dates.max.end_of_month.end_of_day
    end

    def closed_blockers(date)
      month = date.beginning_of_month
      ClosedPeriod.exists?(month: month) ? ["#{month.strftime('%Y-%m')} 已关账，不可变更"] : []
    end

    def summary(rows)
      counts = rows.group_by { |r| r[:action].to_s }.transform_values(&:size)
      {
        "rows" => rows.map { |r| stringify(r) },
        "create" => counts["create"].to_i, "update" => counts["update"].to_i,
        "void" => counts["void"].to_i, "delete" => counts["delete"].to_i,
        "conflict" => counts["conflict"].to_i, "skip" => counts["none"].to_i
      }
    end

    def stringify(row)
      row.transform_values { |v| v.is_a?(Symbol) ? v.to_s : v }
    end

    # ---------- 1) 订单核对 ----------
    def diff_orders(sheet, range)
      sheet.default_sheet = "订单核对"
      sys = OrderLine.joins(:order).includes(order: :customer)
                     .where(orders: { kind: %w[normal return], status: "submitted", created_at: range })
                     .index_by(&:id)
      by_po_line = sys.values.group_by { |l| [l.order.po_number, l.line_no] }
      by_po_gv = sys.values.group_by { |l| [l.order.po_number, l.generic_part_no, l.version.presence] }

      matched = []
      rows = []
      (3..sheet.last_row).each do |i|
        po = text(sheet.cell(i, 2))
        next if po.blank?

        r = { row_no: i, recv_date: parse_date(sheet.cell(i, 1)), po: po,
              line_no: sheet.cell(i, 3).to_i, generic: text(sheet.cell(i, 4)),
              version: text(sheet.cell(i, 5)).presence, customer_name: text(sheet.cell(i, 6)),
              currency: text(sheet.cell(i, 7)).presence, qty: sheet.cell(i, 8).to_i,
              price: sheet.cell(i, 9).present? ? sheet.cell(i, 9).to_f : nil,
              req_date: parse_date(sheet.cell(i, 10)), remark: text(sheet.cell(i, 11)),
              line_id: sheet.cell(i, 14).to_i,
              fingerprint: text(sheet.cell(i, 15)) }

        line = sys[r[:line_id].positive? ? r[:line_id] : nil]
        stale = false
        if line
          stale = line.updated_at.strftime("%Y-%m-%d %H:%M:%S") != r[:fingerprint]
        else # 指纹匹配不到 → 按键列（订单号+行号，再 订单号+型号+版本）
          cands = by_po_line[[r[:po], r[:line_no].positive? ? r[:line_no] : nil]] || []
          cands = by_po_gv[[r[:po], r[:generic], r[:version]]] || [] if cands.empty?
          if cands.many?
            rows << conflict_row(i, po, ["「#{po}」按键列匹配到 #{cands.size} 行，无法区分，请人工处理"])
            next
          end
          line = cands.first
        end

        if line # ---- 修改候选 ----
          matched << line.id
          o = line.order
          blockers = closed_blockers(o.created_at)
          warnings = stale ? ["导出后系统该行已变更，以系统当前值比对"] : []
          if r[:qty].positive? && r[:qty] < line.quantity &&
             (line.delivered_qty.positive? || line.allocated_qty.positive?)
            blockers << "数量缩减（#{line.quantity}→#{r[:qty]}）且行已分配/已出库，不可自动改"
          end
          fields = {}
          fields["接收日期"] = [o.created_at.to_date, r[:recv_date]] if r[:recv_date] && o.created_at.to_date != r[:recv_date]
          fields["数量"] = [line.quantity, r[:qty]] if r[:qty].positive? && line.quantity != r[:qty]
          if r[:price] && (line.unit_price.round(2) - r[:price]).abs > 0.01
            fields["含税单价"] = [line.unit_price.round(2), r[:price]]
            price = strict_price(o.customer, line.generic_part_no, r[:recv_date] || o.created_at.to_date, r[:price])
            if price
              warnings << "新单价命中报价 #{price.price_number}，应用后将重快照成分"
            else
              blockers << "含税单价 #{r[:price]}（接收日期 #{r[:recv_date]&.to_s || o.created_at.to_date}）无匹配报价（D18）"
            end
          end
          fields["要求交期"] = [line.required_delivery_date, r[:req_date]] if line.required_delivery_date != r[:req_date] && r[:req_date]
          fields["备注"] = [line.remark, r[:remark]] if line.remark.to_s != r[:remark] && r[:remark].present?
          fields["版本"] = [line.version, r[:version]] if line.version.to_s != r[:version] && r[:version].present?
          action = blockers.any? ? :conflict : (fields.any? ? :update : :none)
          rows << { row_no: i, key: "#{r[:po]}-#{line.line_no}", action: action,
                    fields: fields, blockers: blockers, warnings: warnings,
                    attrs: action == :update ? update_attrs(line, fields, r) : nil }
        else # ---- 新增候选 ----
          customer = Customer.find_by(name_zh: r[:customer_name]) || Customer.find_by(name: r[:customer_name])
          blockers = []
          blockers << "客户「#{r[:customer_name]}」不存在" unless customer
          dup_ln = by_po_line[[r[:po], r[:line_no]]] if r[:line_no].positive?
          blockers << "「#{r[:po]}」已存在行号 #{r[:line_no]}（新增行请换行号）" if dup_ln.present?
          price = customer && r[:price] ? strict_price(customer, r[:generic], r[:recv_date] || Date.current, r[:price]) : nil
          blockers << "含税单价 #{r[:price]}（#{r[:recv_date]}）无匹配报价（D18）" if customer && price.nil?
          rows << { row_no: i, key: "#{r[:po]}-#{r[:line_no].positive? ? r[:line_no] : r[:generic]}",
                    action: blockers.any? ? :conflict : :create, fields: {},
                    blockers: blockers, warnings: [],
                    attrs: blockers.any? ? nil : create_order_attrs(r, customer, price) }
        end
      end

      # 删除候选：系统有 Excel 无（D15：已分配/已出库 → 冲突；否则已提交作废）
      sys.values.reject { |l| matched.include?(l.id) }.each do |line|
        o = line.order
        blockers = []
        blockers << "已出库 #{line.delivered_qty} pcs，删除请人工处理" if line.delivered_qty.positive?
        blockers << "已签发分配 #{line.allocated_qty} pcs，删除请人工处理" if line.allocated_qty.positive?
        blockers += closed_blockers(o.created_at)
        rows << { row_no: nil, key: line.display_no,
                  action: blockers.any? ? :conflict : :void, fields: { "数量" => [line.quantity, 0] },
                  blockers: blockers, warnings: [], attrs: { "id" => line.id } }
      end
      rows.sort_by! { |r| r[:row_no] || 99_999 }
      summary(rows)
    end

    def conflict_row(i, po, blockers)
      { row_no: i, key: po, action: :conflict, fields: {}, blockers: blockers, warnings: [], attrs: nil }
    end

    def create_order_attrs(r, customer, price)
      { "po" => r[:po], "line_no" => r[:line_no].positive? ? r[:line_no] : nil,
        "recv_date" => r[:recv_date]&.to_s, "generic" => r[:generic], "version" => r[:version],
        "qty" => r[:qty], "customer_id" => customer.id, "currency" => r[:currency].presence || customer.currency,
        "req_date" => r[:req_date]&.to_s, "remark" => r[:remark],
        "price_id" => price&.id, "base_price" => price&.base_price,
        "v1_price" => price&.v1_price, "v2_price" => price&.v2_price }
    end

    def update_attrs(line, fields, r)
      a = { "id" => line.id, "qty" => fields["数量"]&.last,
            "recv_date" => fields["接收日期"]&.last&.to_s,
            "req_date" => fields["要求交期"]&.last&.to_s, "remark" => fields["备注"]&.last,
            "version" => fields["版本"]&.last }.compact
      if fields.key?("含税单价")
        o = line.order
        as_of = fields.dig("接收日期", 1) || o.created_at.to_date
        price = strict_price(o.customer, line.generic_part_no, as_of, fields["含税单价"].last)
        a.merge!("price_id" => price.id, "base_price" => price.base_price,
                 "v1_price" => price.v1_price, "v2_price" => price.v2_price)
      end
      a
    end

    # D18 严格价格匹配（与客户订单导入同口径；核对新增行数量未知时取最高可用档）
    def strict_price(customer, generic, as_of, total)
      scope = Price.where(part_number: generic, status: %w[approved active], customer_id: customer.id)
                   .where("effective_from IS NULL OR effective_from <= ?", as_of)
                   .where("expired_at IS NULL OR expired_at >= ?", as_of)
      cands = scope.select { |p| (p.price.to_d - total.to_d).abs <= 0.01 }
      return nil if cands.empty?

      tiers = cands.filter_map { |p| [Price.numeric_condition(p), p] }
      if tiers.empty?
        cands.max_by { |p| [p.effective_from || Date.new(0), p.id] }
      else
        c_pick = tiers.transpose.first.max # 最高档（核对场景不约束数量档）
        tiers.select { |c, _| c == c_pick }
             .max_by { |_, p| [p.effective_from || Date.new(0), p.id] }.last
      end
    end

    # ---------- 2) 销售订单核对 ----------
    def diff_sales_orders(sheet, range)
      sheet.default_sheet = "销售订单核对"
      sys = ProductionLine.joins(:sales_order).includes(:item, sales_order: :customer)
                          .where(sales_orders: { status: "submitted", created_at: range })
                          .index_by(&:id)
      matched = []
      rows = []
      (3..sheet.last_row).each do |i|
        serial = text(sheet.cell(i, 2))
        next if serial.blank?

        r = { row_no: i, order_date: parse_date(sheet.cell(i, 1)), serial: serial,
              part: text(sheet.cell(i, 3)), customer_name: text(sheet.cell(i, 4)),
              qty: sheet.cell(i, 5).to_i, version: text(sheet.cell(i, 6)),
              full_name: text(sheet.cell(i, 7)),
              line_id: sheet.cell(i, 10).to_i, fingerprint: text(sheet.cell(i, 11)) }

        line = sys[r[:line_id].positive? ? r[:line_id] : nil]
        stale = false
        if line
          stale = line.updated_at.strftime("%Y-%m-%d %H:%M:%S") != r[:fingerprint]
        else
          generic, = Item.parse_full_part_no(r[:part])
          cands = sys.values.select { |pl| pl.sales_order.serial_number == r[:serial] &&
                                            pl.item&.generic_part_no == generic }
          line = cands.one? ? cands.first : nil
          if cands.many?
            rows << conflict_row(i, serial, ["「#{serial} #{generic}」匹配到 #{cands.size} 行，请人工处理"])
            next
          end
        end

        if line
          matched << line.id
          so = line.sales_order
          blockers = closed_blockers(so.created_at)
          warnings = stale ? ["导出后系统该行已变更，以系统当前值比对"] : []
          if r[:qty].positive? && r[:qty] < line.quantity && line.shipped_qty.positive?
            blockers << "数量缩减（#{line.quantity}→#{r[:qty]}）低于已出库（#{line.shipped_qty}），不可自动改"
          end
          fields = {}
          fields["下单日期"] = [so.created_at.to_date, r[:order_date]] if r[:order_date] && so.created_at.to_date != r[:order_date]
          fields["数量"] = [line.quantity, r[:qty]] if r[:qty].positive? && line.quantity != r[:qty]
          fields["版本"] = [line.version, r[:version]] if line.version.to_s != r[:version] && r[:version].present?
          fields["统一编号"] = [line.full_name, r[:full_name]] if line.full_name.to_s != r[:full_name] && r[:full_name].present?
          action = blockers.any? ? :conflict : (fields.any? ? :update : :none)
          rows << { row_no: i, key: "#{serial} #{line.item&.generic_part_no}#{line.suffix}", action: action,
                    fields: fields, blockers: blockers, warnings: warnings,
                    attrs: action == :update ? { "id" => line.id, "qty" => fields["数量"]&.last,
                                                 "version" => fields["版本"]&.last,
                                                 "full_name" => fields["统一编号"]&.last,
                                                 "order_date" => fields["下单日期"]&.last&.to_s }.compact : nil }
        else # ---- 新增候选：六联单号不存在 → 建头+行；存在 → 追加行 ----
          so = SalesOrder.find_by(serial_number: r[:serial])
          customer = Customer.find_by(name_zh: r[:customer_name]) || Customer.find_by(name: r[:customer_name])
          generic, suffix = Item.parse_full_part_no(r[:part])
          item = Item.find_by(generic_part_no: generic) || Item.find_by_any_part_no(r[:part])
          blockers = []
          blockers << "客户「#{r[:customer_name]}」不存在" unless customer
          blockers << "产品「#{r[:part]}」未建档" unless item
          rows << { row_no: i, key: "#{serial} #{r[:part]}",
                    action: blockers.any? ? :conflict : :create, fields: {},
                    blockers: blockers, warnings: so ? [] : ["新建六联单 #{r[:serial]}（无分配对，后续需手工分配）"],
                    attrs: blockers.any? ? nil :
                             { "serial" => r[:serial], "order_date" => r[:order_date]&.to_s,
                               "customer_id" => customer&.id, "item_id" => item&.id,
                               "suffix" => suffix.presence || item&.suffix.presence,
                               "qty" => r[:qty], "version" => r[:version], "full_name" => r[:full_name],
                               "so_new" => so.nil? } }
        end
      end

      sys.values.reject { |l| matched.include?(l.id) }.each do |line|
        so = line.sales_order
        blockers = []
        blockers << "已出库 #{line.shipped_qty} pcs，删除请人工处理" if line.shipped_qty.positive?
        blockers += closed_blockers(so.created_at)
        rows << { row_no: nil, key: "#{so.serial_number} #{line.item&.generic_part_no}#{line.suffix}",
                  action: blockers.any? ? :conflict : :void,
                  fields: { "数量" => [line.quantity, 0] },
                  blockers: blockers, warnings: [], attrs: { "id" => line.id } }
      end
      rows.sort_by! { |r| r[:row_no] || 99_999 }
      summary(rows)
    end

    # ---------- 3) 发货核对：仅支持 Excel 补录新增（系统多录提示人工处理）----------
    def diff_shipments(sheet, range)
      sheet.default_sheet = "发货核对"
      sys = Shipment.where(shipped_at: range).includes(:sales_order)
      sys_by_key = sys.map { |sh| [[sh.sales_order.serial_number, sh.shipped_at.to_date, sh.tracking_no], sh] }.to_h

      rows = []
      matched = []
      (3..sheet.last_row).each do |i|
        serial = text(sheet.cell(i, 2))
        next if serial.blank?

        r = { row_no: i, ship_date: parse_date(sheet.cell(i, 1)), serial: serial,
              part: text(sheet.cell(i, 3)), qty: sheet.cell(i, 5).to_i,
              tracking: text(sheet.cell(i, 6)) }
        existing = sys_by_key[[r[:serial], r[:ship_date], r[:tracking]]]
        if existing
          matched << existing.id
          rows << { row_no: i, key: "#{serial} #{r[:ship_date]} #{r[:tracking]}",
                    action: :none, fields: {}, blockers: [], warnings: [], attrs: nil }
          next
        end

        so = SalesOrder.find_by(serial_number: r[:serial])
        generic, suffix = Item.parse_full_part_no(r[:part])
        pl = so&.production_lines&.joins(:item)&.find_by(items: { generic_part_no: generic }) ||
             so&.production_lines&.find_by(suffix: suffix.presence)
        blockers = []
        blockers << "六联单「#{r[:serial]}」不存在" unless so
        blockers << "六联单「#{r[:serial]}」无「#{generic}」行" if so && pl.nil?
        if pl && r[:qty].positive? && pl.reload.shipped_qty + r[:qty] > pl.quantity
          blockers << "累计发货将超六联单数量（#{pl.shipped_qty}+#{r[:qty]} > #{pl.quantity}）"
        end
        blockers += closed_blockers(r[:ship_date] || Date.current) if r[:ship_date]
        rows << { row_no: i, key: "#{serial} #{r[:ship_date]} #{r[:tracking]}",
                  action: blockers.any? ? :conflict : :create, fields: {},
                  blockers: blockers, warnings: [],
                  attrs: blockers.any? ? nil :
                           { "serial" => r[:serial], "ship_date" => r[:ship_date]&.to_s,
                             "production_line_id" => pl&.id, "qty" => r[:qty],
                             "tracking" => r[:tracking],
                             "source_key" => [r[:serial], r[:ship_date]&.to_s, r[:tracking]].join("|") } }
      end

      (sys.reject { |sh| matched.include?(sh.id) }).each do |sh|
        rows << { row_no: nil, key: "#{sh.sales_order.serial_number} #{sh.shipped_at.to_date} #{sh.tracking_no}",
                  action: :none, fields: {}, blockers: [],
                  warnings: ["系统多录：Excel 无此出库单，请人工到出货页处理"], attrs: nil }
      end
      rows.sort_by! { |r| r[:row_no] || 99_999 }
      summary(rows)
    end

    # ---------- 应用 ----------
    def apply_section(section, kind)
      return {} unless section

      count = Hash.new(0)
      section["rows"].each do |r|
        row = r.transform_keys(&:to_sym)
        next if row[:action] == "conflict" || row[:action] == "none" || row[:blockers].present?

        case row[:action]
        when "create" then send("apply_create_#{kind}", row[:attrs])
        when "update" then send("apply_update_#{kind}", row[:attrs])
        when "void" then apply_void(kind, row[:attrs]["id"])
        end
        count[row[:action]] += 1
      end
      count
    end

    def apply_create_orders(a)
      order = Order.find_or_initialize_by(po_number: a["po"])
      if order.new_record?
        customer = Customer.find(a["customer_id"])
        order = Order.build_with_customer(customer, po_number: a["po"])
        order.currency = a["currency"].presence || order.currency
        order.created_at = a["recv_date"] if a["recv_date"]
        order.snapshot_exchange_rate!
        order.status = "submitted"
        order.save!
      elsif a["recv_date"] && order.created_at.to_date != Date.parse(a["recv_date"])
        order.update!(created_at: a["recv_date"])
      end
      line = order.order_lines.build(generic_part_no: a["generic"], version: a["version"],
                                     quantity: a["qty"], full_part_no: a["generic"],
                                     required_delivery_date: a["req_date"],
                                     remark: a["remark"].presence)
      line.line_no = a["line_no"] if a["line_no"]
      line.assign_attributes(base_price: a["base_price"], v1_price: a["v1_price"],
                             v2_price: a["v2_price"], price_id: a["price_id"])
      line.save!
    end

    def apply_update_orders(a)
      line = OrderLine.find(a["id"])
      line.quantity = a["qty"] if a["qty"]
      line.version = a["version"] if a.key?("version")
      line.required_delivery_date = a["req_date"] if a.key?("req_date")
      line.remark = a["remark"] if a.key?("remark")
      if a["price_id"]
        line.assign_attributes(base_price: a["base_price"], v1_price: a["v1_price"],
                               v2_price: a["v2_price"], price_id: a["price_id"])
      end
      line.save!
      line.order.update!(created_at: a["recv_date"]) if a["recv_date"] && line.order.created_at.to_date != Date.parse(a["recv_date"])
    end

    def apply_create_sales_orders(a)
      so = a["so_new"] ? nil : SalesOrder.find_by(serial_number: a["serial"])
      if so.nil?
        so = SalesOrder.new(serial_number: a["serial"])
        so.initialize_order_header(Customer.find(a["customer_id"]))
        so.exchange_rate = 1 if so.exchange_rate.blank?
        so.status = "submitted"
        so.created_at = a["order_date"] if a["order_date"]
      end
      item = Item.find(a["item_id"])
      so.production_lines.build(item: item, suffix: a["suffix"].presence, quantity: a["qty"],
                                version: a["version"].presence, full_name: a["full_name"].presence,
                                source: "check")
      so.save!
    end

    def apply_update_sales_orders(a)
      line = ProductionLine.find(a["id"])
      line.quantity = a["qty"] if a["qty"]
      line.version = a["version"] if a.key?("version")
      line.full_name = a["full_name"] if a.key?("full_name")
      line.save!
      line.sales_order.update!(created_at: a["order_date"]) if a["order_date"] && line.sales_order.created_at.to_date != Date.parse(a["order_date"])
    end

    def apply_create_shipments(a)
      return if Shipment.exists?(source_key: a["source_key"]) # 幂等

      so = SalesOrder.find_by(serial_number: a["serial"])
      sh = Shipment.new(sales_order: so, shipped_at: a["ship_date"],
                        tracking_no: a["tracking"].presence, source_key: a["source_key"])
      sh.shipment_lines.build(production_line_id: a["production_line_id"], quantity: a["qty"])
      sh.save!
    end

    # D15：已提交行作废标记（remark 前缀 + 数量置 0），保留追溯
    def apply_void(kind, id)
      line = kind == :orders ? OrderLine.find(id) : ProductionLine.find(id)
      old_remark = line.remark.to_s
      return if old_remark.include?(VOID_MARK)

      line.update_columns(remark: "#{VOID_MARK}#{old_remark}", quantity: 0, updated_at: Time.current)
    end
  end
end
