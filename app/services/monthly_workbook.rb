require "caxlsx"

# 按月导出工作簿（对账模板）：列序与列名严格对齐财务对账用 Excel（cute_erp_202610_new）
# 未税 = 含税 ÷ 1.13；声码名称 = 产品档案 extra_item/extra_item2 对应 Item 名称
# 空列 = 对账表保留列（供 Excel 侧手工填写，导出为空以保证可直接复制粘贴）
# month_date 传 nil = 全量模式（导出所有时间段数据）：三处单据过滤（客户订单/六联单/出库单）
# 的区间放开为全时间；价格/阶梯/客户/产品本就是全量
class MonthlyWorkbook
  TAX_FACTOR = 1.13 # 增值税 13%，含税 → 未税
  ALL_RANGE = Date.new(1970, 1, 1).beginning_of_day..Date.new(9999, 12, 31).end_of_day

  def self.generate(month_date = nil)
    new(month_date).call
  end

  def initialize(month_date)
    @all_periods = month_date.nil?
    @month = month_date&.beginning_of_month
    # 区间用日界时间而非 Date 区间：datetime 列对 Date 端点按 UTC 午夜 cast（北京时区即当日 08:00），
    # 会漏掉 1 日 0~8 点与末日 8 点之后的单据
    @range = @all_periods ? ALL_RANGE : @month.beginning_of_month.beginning_of_day..@month.end_of_month.end_of_day
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
    customers_sheet(wb, title)
    products_sheet(wb, title)

    package.to_stream.read
  end

  private

  def sheet(wb, style, name, headers)
    wb.add_worksheet(name: name) do |ws|
      ws.add_row(headers, style: style)
      yield ws
    end
  end

  # ---- 1 客户订单（25 列；10-12 为保留空列；含冲销单与未交订单） ----
  def customer_orders_sheet(wb, style)
    headers = ["接收日期", "客户", "订单号", "通用型号", "版本", "数量", "含税单价", "要求交期",
               "特殊要求", "", "", "", "未税单价", "未税金额", "声码1名称", "声码名称2",
               "芯片未税金额", "声码1未税金额", "声码2未税金额", "未交订单数",
               "未交芯片金额(未税)", "未交声码1金额", "未交声码2金额", "币别", "类型"]

    sheet(wb, style, "客户订单", headers) do |ws|
      OrderLine.joins(:order)
               .includes(order: :customer, production_allocations: :order_line)
               .where(orders: { kind: %w[normal return], created_at: @range })
               .order("orders.po_number", "order_lines.line_no").find_each do |line|
        o = line.order
        item = line.order_item
        open = o.return? ? 0 : line.open_qty
        ws.add_row [o.created_at.to_date, cust_name(o.customer), o.po_number, line.generic_part_no,
                    line.version, line.quantity, line.unit_price,
                    line.required_delivery_date&.to_date, line.remark,
                    nil, nil, nil,
                    ex_tax(line.unit_price), ex_tax(line.total_price), # 金额 = 先乘数量后除 1.13（单价舍入不得放大进金额）
                    component_name(item, :extra_item), component_name(item, :extra_item2),
                    ex_tax(line.quantity * (line.base_price || 0)).round(2),
                    ex_tax(line.quantity * (line.v1_price || 0)).round(2),
                    ex_tax(line.quantity * (line.v2_price || 0)).round(2),
                    open.to_f.round(2),
                    ex_tax(open * (line.base_price || 0)).round(2),
                    ex_tax(open * (line.v1_price || 0)).round(2),
                    ex_tax(open * (line.v2_price || 0)).round(2),
                    o.currency, o.return? ? "冲销" : "订单"]
      end
    end
  end

  # ---- 2 生产订单-六联单（9 列 + 保留空列 + 固定 5 组分配对） ----
  ALLOC_PAIRS = 5

  def six_part_sheet(wb, style)
    headers = ["六联单号", "下单日期", "客户", "产品", "数量", "含税单价", "版本",
               "约定发货日期", "发货数量", nil] +
              ALLOC_PAIRS.times.flat_map { |i| ["订单#{i + 1}", "分配量#{i + 1}"] }

    sheet(wb, style, "生产订单-六联单", headers) do |ws|
      SalesOrder.includes(:customer, :production_lines, { production_lines: { production_allocations: { order_line: :order } } })
                .where(created_at: @range).order(:serial_number).find_each do |so|
        so.production_lines.each do |line|
          allocs = line.production_allocations.includes(order_line: :order).first(ALLOC_PAIRS)
          pairs = allocs.flat_map { |a| [a.order_line&.display_no, a.quantity] }
          pairs += [nil] * (ALLOC_PAIRS * 2 - pairs.size)
          ws.add_row [so.serial_number, so.created_at.to_date, cust_name(so.customer), line.part_number,
                      line.quantity, line.unit_price, line.version,
                      so.required_date&.to_date, line.shipped_qty, nil] + pairs
        end
      end
    end
  end

  # ---- 3 出库单（16 列；6-8 为保留空列；快递号在末尾） ----
  def shipments_sheet(wb, style)
    headers = ["日期", "客户", "六联单号", "产品", "数量", "", "", "",
               "RMB单价含税", "销售额（不含税）", "声码器1", "声码器2",
               "芯片销售额(不含税)", "声码1销售额(不含税)", "声码2销售额(不含税)", "快递号"]

    sheet(wb, style, "出库单", headers) do |ws|
      ShipmentLine.joins(shipment: { sales_order: :customer })
                  .includes(shipment: { sales_order: :customer },
                            production_line: { item: [], production_allocations: { order_line: :order } })
                  .where(shipments: { shipped_at: @range })
                  .order("shipments.shipped_at").find_each do |sl|
        pl = sl.production_line
        # 币别：分配订单快照优先，无分配回退客户现币别（旧数据快照失真时仍按客户口径）
        currency = pl&.production_allocations&.first&.order_line&.order&.currency ||
                   sl.shipment.sales_order.customer.currency.presence || "RMB"
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
                    nil, nil, nil,
                    unit_rmb, ex_tax(qty * (pl&.unit_price || 0) * rate),
                    component_name(item, :extra_item), component_name(item, :extra_item2),
                    ex_tax(qty * chip * rate), ex_tax(qty * soft1 * rate), ex_tax(qty * soft2 * rate),
                    sl.shipment.tracking_no]
      end
    end
  end

  # ---- 4 价格（17 列） ----
  def prices_sheet(wb, style)
    headers = ["Price_number", "生效日期", "失效日期", "客户", "通用型号", "总单价",
               "芯片", "声码1", "声码2", "订单量", "ODM/OEM", "", "PRR", "", "remark",
               "币别", "状态"]

    sheet(wb, style, "价格", headers) do |ws|
      Price.where(status: %w[approved active]).order(:customer_name, :part_number, :condition).find_each do |pr|
        ws.add_row [pr.price_number, pr.effective_from&.to_date, pr.expired_at&.to_date,
                    pr.customer_name, pr.part_number, pr.price,
                    pr.base_price, pr.v1_price, pr.v2_price, pr.condition,
                    pr.customer&.sales_type, nil,
                    pr.is_prr == 1 ? "✂" : nil, nil,
                    pr.remark, pr.currency, "生效"]
      end
    end
  end

  # ---- 5 阶梯（最新批次，OEM/ODM 并排，缩写档位表头） ----
  def tiers_sheet(wb, style)
    tiers = PriceListEntry::TIERS
    labels = PriceListEntry::TIER_LABELS
    release = PriceListRelease.latest
    headers = ["通用型号", "发布日期", release&.released_at&.to_date&.strftime("%Y-%m-%d")] + labels + [""] + labels

    sheet(wb, style, "阶梯(最新批次)", headers) do |ws|
      next unless release

      release.entries.ordered.group_by(&:generic_part_no).each do |gen, entries|
        oem = tiers.map do |t|
          (e = entries.find { |x| x.sell_by == "OEM" && x.min_qty == t }) ? e.price.to_f.round(2) : nil
        end
        odm = tiers.map do |t|
          (e = entries.find { |x| x.sell_by == "ODM" && x.min_qty == t }) ? e.price.to_f.round(2) : nil
        end
        ws.add_row [gen, nil, nil] + oem + [nil] + odm
      end

      # 发布日期行（导入时作为批次日期）
      ws.add_row [nil]
      ws.add_row ["发布日期", release.released_at&.to_date]
    end
  end  # ---- 6 客户（15 列，主数据） ----
  def customers_sheet(wb, style)
    headers = ["英文名", "中文名", "公司全称", "区域", "销售类型", "代理商", "联系人", "电话",
               "地址", "收货联系人", "收货地址", "收货电话", "币别",
               "<html><b>付款方式</b></html>", "建立日期"]

    sheet(wb, style, "客户", headers) do |ws|
      Customer.order(:name).find_each do |c|
        ws.add_row [c.name, c.name_zh, c.full_name, c.territory, c.sales_type,
                    c.disty&.name, c.contact, c.telephone, c.address,
                    c.ship_contact, c.ship_address, c.ship_telephone,
                    c.currency, c.payment, c.since&.to_date]
      end
    end
  end

  # ---- 7 产品（14 列，主数据） ----
  def products_sheet(wb, style)
    headers = ["型号", "产品名称", "描述", "类别", "产品族", "组装方式", "base_item",
               "extra_item", "extra_item2", "", "", "状态", "包装", "最小起订量"]

    sheet(wb, style, "产品", headers) do |ws|
      Item.order(:generic_part_no, :suffix).find_each do |i|
        ws.add_row [i.partNo, i.name, i.description, i.group, i.family, i.assembled,
                    i.base_item, i.extra_item, i.extra_item2,
                    nil, nil, i.index.positive? ? "active" : "隐藏", i.package, i.moq]
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
