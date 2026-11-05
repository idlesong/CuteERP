require "caxlsx"

# 核对导出（phase3 3.1）：系统 ↔ Excel 核对用工作簿，四张核对表（每表一个 sheet）：
#   订单核对 / 销售订单核对 / 发货核对 / 未交订单核对
# - 指纹列（隐藏）：行 id + updated_at —— 核对导入（3.2）精确匹配行与判断"是否真的变了"
# - 每个 sheet 首行写 TEMPLATE_VERSION 并隐藏（列变更时旧文件导入明确报错，D17）
# - 区间：MONTH=（单月切片）或 FROM=/TO=（跨月区间，整月对齐，D22）；查询一律日界时间口径
# - 销售订单核对仅含已提交行（D21，草稿属临时数据不参与正式核对）
# - 未交订单核对 = 截至 TO 月末快照（delivered/open_qty 按 as_of 口径，未来出库不污染历史）
class ReconciliationWorkbook
  TEMPLATE_VERSION = 1
  SHEET_NAMES = %w[订单核对 销售订单核对 发货核对 未交订单核对].freeze

  class << self
    # params: { month: "2026-05" } 或 { from: "2025-12", to: "2026-05" }（可缺省 to = from）
    # 返回 { data: xlsx 二进制, from: Date, to: Date, filename: }
    def generate(params = {})
      from, to = resolve_months(params)
      range = from.beginning_of_month.beginning_of_day..to.end_of_month.end_of_day
      as_of = to.end_of_month.end_of_day

      package = Axlsx::Package.new
      wb = package.workbook
      head_style = wb.styles.add_style(b: true, bg_color: "D9E1F2")
      ver_style = wb.styles.add_style(b: true, font_color: "808080")

      build_sheets(wb, head_style, ver_style, from, to, range, as_of)
      { data: package.to_stream.read, from: from, to: to,
        filename: "核对导出_#{from.strftime('%Y%m')}-#{to.strftime('%Y%m')}.xlsx" }
    end

    # 区间参数解析（D22：整月对齐）；非法月份抛错由控制器转 flash
    def resolve_months(params)
      month = params[:month].presence
      from_s = params[:from].presence
      raise "请提供 MONTH（单月）或 FROM/TO（跨月区间）" if month.blank? && from_s.blank?

      from = parse_month(month || from_s)
      to = month.blank? ? parse_month(params[:to].presence || from_s) : from
      from, to = to, from if from > to
      [from, to]
    end

    private

    def parse_month(text)
      Date.strptime(text.to_s.strip, "%Y-%m").beginning_of_month
    rescue ArgumentError, TypeError
      raise "月份格式应为 YYYY-MM：#{text}"
    end

    # 每表：首行 TEMPLATE_VERSION（隐藏）→ 表头 → 数据；指纹列隐藏
    def build_sheets(wb, head_style, ver_style, from, to, range, as_of)
      [
        sheet_orders(range),
        sheet_sales_orders(range),
        sheet_shipments(range),
        sheet_backlog(from, to, as_of)
      ].each do |spec|
        wb.add_worksheet(name: spec[:name]) do |ws|
          ws.add_row(["TEMPLATE_VERSION", TEMPLATE_VERSION], style: ver_style)
          ws.add_row(spec[:headers], style: head_style)
          spec[:rows].each { |row| ws.add_row(row) }
          ws.rows.first.hidden = true                      # 版本行隐藏（导入器读 A1/B1 校验，D17）
          ws.column_info[spec[:fingerprint_from]..].each { |col| col.hidden = true }
        end
      end
    end

    # 1) 订单核对：区间内接收的已提交订单行（含冲销负数行；草稿不核对）
    def sheet_orders(range)
      headers = %w[接收日期 订单号 行号 通用型号 版本 客户 币别 数量 含税单价 要求交期 特殊要求 单据类型 状态 行ID 更新时间]
      rows = OrderLine.joins(:order).includes(order: :customer)
                      .where(orders: { kind: %w[normal return], status: "submitted",
                                       created_at: range })
                      .order("orders.created_at", "orders.po_number", "order_lines.line_no")
                      .map do |l|
                        o = l.order
                        [l.order.created_at.to_date, o.po_number, l.line_no, l.generic_part_no,
                         l.version, o.customer.name_zh.presence || o.customer.name,
                         o.currency, l.quantity, l.unit_price.round(2),
                         l.required_delivery_date, l.remark,
                         o.kind == "return" ? "冲销" : "正常", o.status,
                         l.id, l.updated_at.strftime("%Y-%m-%d %H:%M:%S")]
                      end
      { name: "订单核对", headers: headers, rows: rows, fingerprint_from: 13 }
    end

    # 2) 销售订单核对：区间内下发的已提交六联单行（D21：草稿不导出不核对）
    def sheet_sales_orders(range)
      headers = %w[下单日期 六联单号 产品 客户 数量 版本 统一编号 加权单价 状态 行ID 更新时间]
      rows = ProductionLine.joins(:sales_order).includes(:item, sales_order: :customer)
                           .where(sales_orders: { status: "submitted", created_at: range })
                           .order("sales_orders.created_at", "sales_orders.serial_number", "production_lines.id")
                           .map do |pl|
                             so = pl.sales_order
                             part = [pl.item&.generic_part_no, pl.suffix.presence].compact.join
                             [so.created_at.to_date, so.serial_number, part,
                              so.customer.name_zh.presence || so.customer.name,
                              pl.quantity, pl.version, pl.full_name, pl.unit_price.round(2),
                              so.status, pl.id, pl.updated_at.strftime("%Y-%m-%d %H:%M:%S")]
                           end
      { name: "销售订单核对", headers: headers, rows: rows, fingerprint_from: 9 }
    end

    # 3) 发货核对：区间内的出库明细（行级，含快递号）
    def sheet_shipments(range)
      headers = %w[出库日期 六联单号 型号 客户 数量 快递号 出库单ID 明细行ID]
      rows = ShipmentLine.joins(:shipment, shipment: { sales_order: :customer })
                         .includes(shipment: { sales_order: :customer }, production_line: :item)
                         .where(shipments: { shipped_at: range })
                         .order("shipments.shipped_at", "shipments.id", "shipment_lines.id")
                         .map do |sl|
                           sh = sl.shipment
                           pl = sl.production_line
                           [sh.shipped_at.to_date, sh.sales_order.serial_number,
                            pl&.part_number,
                            sh.sales_order.customer.name_zh.presence || sh.sales_order.customer.name,
                            sl.quantity, sh.tracking_no, sh.id, sl.id]
                         end
      { name: "发货核对", headers: headers, rows: rows, fingerprint_from: 6 }
    end

    # 4) 未交订单核对：截至 TO 月末快照（as_of 口径；open_qty ≠ 0 的行才列出）
    def sheet_backlog(_from, to, as_of)
      headers = %w[接收日期 订单号 行号 通用型号 客户 币别 订单量 冲销量 已出货 未交数量 含税单价 未交金额本币 汇率 未交金额折RMB 行ID]
      rows = OrderLine.joins(:order).includes(order: :customer)
                      .where(orders: { kind: "normal", status: "submitted",
                                       created_at: ..as_of })
                      .order("orders.created_at", "orders.po_number", "order_lines.line_no")
                      .filter_map do |l|
                        o = l.order
                        qty = l.open_qty(as_of: as_of)
                        next if qty.zero?

                        rate = o.currency == "RMB" ? 1 : (ExchangeRate.rate_for(o.created_at.beginning_of_month, o.currency) || 1)
                        [o.created_at.to_date, o.po_number, l.line_no, l.generic_part_no,
                         o.customer.name_zh.presence || o.customer.name, o.currency,
                         l.quantity, l.returned_qty, l.delivered_qty(as_of: as_of),
                         qty.round(2), l.unit_price.round(2),
                         (qty * l.unit_price).round(2), rate, (qty * l.unit_price * rate).round(2), l.id]
                      end
      { name: "未交订单核对", headers: headers, rows: rows, fingerprint_from: 14 }
    end
  end
end
