require "caxlsx"

# 按月导出工作簿（对账模板）：列序对齐财务对账用 Excel（2026-10 修订版）
# 未税 = 含税 ÷ 1.13；声码名称 = 产品档案 extra_item/extra_item2 对应 Item 名称
class MonthlyWorkbook
  TAX_FACTOR = 1.13 # 增值税 13%，含税 → 未税

  def self.generate(month_date)
    new(month_date).call
  end

  def initialize(month_date)
    @month = month_date.beginning_of_month
    @range = @month.all_month
    @item_name_cache = {}
  end

  def call
    package = Axlsx::Package.new
    wb = package.workbook
    title = wb.styles.add_style(b: true, bg_color: "D9E1F2", alignment: { horizontal: :center })

    customer_orders_sheet(wb, title)
    six_part_sheet(wb, title)
    shipments_sheet(wb, title)
    prices_sheet(wb, title)
    tiers_sheet(wb, title)

    package.to_stream.read
  end

  private

  def sheet(wb, style, name, headers)
    wb.add_worksheet(name: name) do |ws|
      ws.add_row(headers, style: style)
      yield ws
    end
  end

  # ---- 1 客户订单（含未税拆分 + 未交订单） ----
  def customer_orders_sheet(wb, style)
    headers = %w[接收日期 客户 订单号 通用型号 版本 数量 含税单价 要求交期 特殊要求 币别
                 未税单价 未税金额 声码1名称 声码名称2 芯片未税金额 声码1未税金额 声码2未税金额
                 未交订单数 未交芯片金额(未税) 未交声码1金额 未交声码2金额]

    sheet(wb, style, "客户订单", headers) do |ws|
      OrderLine.joins(:order)
               .includes(order: :customer, production_allocations: :order_line)
               .where(orders: { kind: "normal", created_at: @range })
               .order("orders.po_number", "order_lines.line_no").find_each do |line|
        o = line.order
        item = line.order_item
        ws.add_row [o.created_at.to_date, cust_name(o.customer), o.po_number, line.generic_part_no,
                    line.version, line.quantity, line.unit_price,
                    line.required_delivery_date&.to_date, line.remark, o.currency,
                    ex_tax(line.unit_price), (ex_tax(line.unit_price) * line.quantity).round(2),
                    component_name(item, :extra_item), component_name(item, :extra_item2),
                    ex_tax(line.quantity * (line.base_price || 0)).round(2),
                    ex_tax(line.quantity * (line.v1_price || 0)).round(2),
                    ex_tax(line.quantity * (line.v2_price || 0)).round(2),
                    line.open_qty.to_f.round(2),
                    ex_tax(line.open_qty * (line.base_price || 0)).round(2),
                    ex_tax(line.open_qty * (line.v1_price || 0)).round(2),
                    ex_tax(line.open_qty * (line.v2_price || 0)).round(2)]
      end
    end
  end

  # ---- 2 生产订单-六联单（含分配对） ----
  def six_part_sheet(wb, style)
    max_allocs = 0
    rows = []
    SalesOrder.includes(:customer, :production_lines, { production_lines: { production_allocations: { order_line: :order } } })
              .where(created_at: @range).order(:serial_number).find_each do |so|
      so.production_lines.each do |line|
        allocs = line.production_allocations.includes(order_line: :order)
        max_allocs = [max_allocs, allocs.size].max
        base = [so.serial_number, so.created_at.to_date, cust_name(so.customer), line.part_number,
                line.quantity, line.unit_price, line.version,
                so.required_date&.to_date, line.shipped_qty]
        pairs = allocs.flat_map { |a| [a.order_line&.display_no, a.quantity] }
        rows << base + pairs
      end
    end

    headers = %w[六联单号 下单日期 客户 产品 数量 含税单价 版本 约定发货日期 发货数量]
    max_allocs.times do |i|
      headers << "订单#{i + 1}" << "分配量#{i + 1}"
    end

    sheet(wb, style, "生产订单-六联单", headers) do |ws|
      rows.each { |r| ws.add_row r }
    end
  end

  # ---- 3 出库单（RMB 含税单价 + 不含税销售额 + 成分销售额） ----
  def shipments_sheet(wb, style)
    headers = %w[日期 客户 六联单号 产品 数量 快递号 RMB单价含税 销售额（不含税）
                 声码器1 声码器2 芯片销售额(不含税) 声码1销售额(不含税) 声码2销售额(不含税)]

    sheet(wb, style, "出库单", headers) do |ws|
      ShipmentLine.joins(shipment: { sales_order: :customer })
                  .includes(shipment: { sales_order: :customer },
                            production_line: { item: [], production_allocations: { order_line: :order } })
                  .where(shipments: { shipped_at: @range })
                  .order("shipments.shipped_at").find_each do |sl|
        pl = sl.production_line
        currency = pl&.production_allocations&.first&.order_line&.order&.currency || "RMB"
        rate = currency == "RMB" ? 1 : (ExchangeRate.rate_for(sl.shipment.shipped_at.beginning_of_month, currency) || 1)

        unit_rmb = ((pl&.unit_price || 0) * rate).round(2)
        qty = sl.quantity
        allocs = pl&.production_allocations || []
        total_alloc = allocs.sum(&:quantity).to_f
        chip = soft1 = soft2 = 0.0
        if total_alloc.positive?
          chip  = allocs.sum { |a| a.quantity * (a.order_line&.base_price || 0).to_f } / total_alloc
          soft1 = allocs.sum { |a| a.quantity * (a.order_line&.v1_price || 0).to_f } / total_alloc
          soft2 = allocs.sum { |a| a.quantity * (a.order_line&.v2_price || 0).to_f } / total_alloc
        end
        item = pl&.item

        ws.add_row [sl.shipment.shipped_at.to_date, cust_name(sl.shipment.sales_order.customer),
                    sl.shipment.sales_order.serial_number, pl&.part_number, qty,
                    sl.shipment.tracking_no, unit_rmb,
                    ex_tax(qty * unit_rmb),
                    component_name(item, :extra_item), component_name(item, :extra_item2),
                    ex_tax(qty * chip * rate), ex_tax(qty * soft1 * rate), ex_tax(qty * soft2 * rate)]
      end
    end
  end

  # ---- 4 价格 + 5 阶梯 ----
  def prices_sheet(wb, style)
    sheet(wb, style, "价格",
          %w[客户 通用型号 芯片 声码1 声码2 总单价 订单量 生效日期 失效日期 币别 状态]) do |ws|
      Price.where(status: %w[approved active]).order(:customer_name, :part_number, :condition).find_each do |pr|
        ws.add_row [pr.customer_name, pr.part_number, pr.base_price, pr.v1_price, pr.v2_price,
                    pr.price, pr.condition, pr.effective_from&.to_date, pr.expired_at&.to_date,
                    pr.currency, "生效"]
      end
    end
  end

  def tiers_sheet(wb, style)
    tiers = PriceListEntry::TIERS
    release = PriceListRelease.latest
    headers = %w[通用型号 渠道] + tiers.map { |t| "#{t}+" }
    sheet(wb, style, "阶梯(最新批次)", headers) do |ws|
      next unless release

      release.entries.ordered.group_by(&:generic_part_no).each do |gen, entries|
        %w[OEM ODM].each do |channel|
          row = [gen, channel]
          tiers.each do |t|
            e = entries.find { |x| x.sell_by == channel && x.min_qty == t }
            row << (e ? e.price : nil)
          end
          ws.add_row row
        end
      end
    end
  end

  # ---- 工具 ----
  def ex_tax(amount_including_tax)
    (amount_including_tax.to_f / TAX_FACTOR).round(2)
  end

  def component_name(item, field)
    return nil if item.nil?

    part_no = item.public_send(field).to_s.strip
    return nil if part_no.empty?

    @item_name_cache[part_no] ||= Item.find_by(generic_part_no: part_no)&.name || part_no
  end

  def cust_name(record)
    record.name_zh.presence || record.name
  end
end
