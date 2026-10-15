require "caxlsx"

# 按月导出工作簿：四表对齐现用 Excel（2.1）
# 1 客户订单 2 生产订单-六联单（含分配对） 3 出库单 4 价格 + 最新阶梯批次
class MonthlyWorkbook
  def self.generate(month_date)
    new(month_date).call
  end

  def initialize(month_date)
    @month = month_date.beginning_of_month
    @range = @month.all_month
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

  def customer_orders_sheet(wb, style)
    sheet(wb, style, "客户订单",
          %w[接收日期 客户 订单号 通用型号 版本 数量 含税单价 要求交期 特殊要求 币别]) do |ws|
      OrderLine.joins(:order)
               .includes(order: :customer)
               .where(orders: { kind: "normal", created_at: @range })
               .order("orders.po_number", "order_lines.line_no").find_each do |line|
        o = line.order
        ws.add_row [o.created_at.to_date, cust_name(o.customer), o.po_number, line.generic_part_no,
                    line.version, line.quantity, line.unit_price,
                    line.required_delivery_date&.to_date, line.remark, o.currency]
      end
    end
  end

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

  def shipments_sheet(wb, style)
    sheet(wb, style, "出库单", %w[日期 客户 六联单号 产品 数量 快递号]) do |ws|
      ShipmentLine.joins(shipment: { sales_order: :customer })
                  .includes(shipment: { sales_order: :customer }, production_line: :item)
                  .where(shipments: { shipped_at: @range })
                  .order("shipments.shipped_at").find_each do |sl|
        ws.add_row [sl.shipment.shipped_at.to_date, cust_name(sl.shipment.sales_order.customer),
                    sl.shipment.sales_order.serial_number, sl.production_line&.part_number,
                    sl.quantity, sl.shipment.tracking_no]
      end
    end
  end

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

  def cust_name(record)
    record.name_zh.presence || record.name
  end
end
