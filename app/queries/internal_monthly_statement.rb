# 月度所有客户内部对账单（销售内部核对用）：
# 五段式：订单核对/出货核对/未交订单/排产核对 + 价格依据（对账月生效中的报价，标记本月新生效/失效），
# 跨全部客户合成，排序 = 币别 → 客户名称 → 日期 → 单据号；
# 单价与金额一律本币（视图按币别拆「人民币/美元」两段分节显示，各自小计）；折 RMB 仅在合计列。
# 排产核对段：分配明细串接（订单行×数量）来自台账，可与 Excel 六联单表 FIFO 公式结果逐行对照。
# 订单/未交段每行带「报价号」（单价来源追溯，内部对账底稿标准：交易明细引用价格主数据行）
class InternalMonthlyStatement
  Row = Struct.new(:date, :doc_no, :customer, :currency, :part, :group, :quantity,
                   :chip_price, :v1_price, :v2_price,
                   :chip_amt, :v1_amt, :v2_amt, :amount, :rate, :amount_rmb, :extra, :price_no)

  # 排产核对段行（生产单无币别语境，独立结构）
  AllocRow = Struct.new(:date, :serial, :customer, :part, :quantity, :version,
                        :alloc_detail, :alloc_total, :shipped_qty, :status)

  # 价格依据段行（flag：本月新生效 / 本月失效 / 空）
  PriceRow = Struct.new(:price_no, :customer, :part, :condition, :chip, :v1, :v2,
                        :price, :effective_from, :expired_at, :currency, :status, :flag)

  attr_reader :month, :order_rows, :shipment_rows, :backlog_rows, :allocation_rows, :price_rows

  def initialize(month)
    @month = month.beginning_of_month
    # 当月区间须用「日界时间」而非 Date 区间：datetime 列对 Date 端点按 UTC 午夜 cast
    # （北京时区即当日 08:00），会漏掉 1 日 0~8 点与末日 8 点之后的单据
    @range = @month.beginning_of_month.beginning_of_day..@month.end_of_month.end_of_day
    @order_rows = []
    @shipment_rows = []
    @backlog_rows = []
    @allocation_rows = []
    @price_rows = []
    build_orders
    build_backlog
    build_shipments
    build_allocations
    build_prices
    sort_rows!
  end

  def build_orders
    # 含冲销单（kind=return，负数金额参与对账）；报价号 = 单价来源追溯（price_id → 报价号）
    OrderLine.joins(order: :customer)
             .includes(:price, order: :customer)
             .where(orders: { kind: %w[normal return], status: "submitted", created_at: @range })
             .order("orders.po_number", "order_lines.line_no").find_each do |line|
      rate = rate_for(@month, line.order.currency)
      qty = line.quantity
      chip = (qty * (line.base_price || 0)).round(2)
      v1 = (qty * (line.v1_price || 0)).round(2)
      v2 = (qty * (line.v2_price || 0)).round(2)
      extra = [line.version, ("冲销" if line.order.return?)].compact.join(" ")
      @order_rows << Row.new(line.order.created_at.to_date, line.display_no,
                             cust_name(line.order.customer), line.order.currency,
                             line.generic_part_no, line.order_item&.group, qty,
                             line.base_price || 0, line.v1_price || 0, line.v2_price || 0,
                             chip, v1, v2, line.total_price.round(2), rate,
                             (line.total_price * rate).round(2), extra, line.price&.price_number)
    end
  end

  def build_backlog
    cutoff = @range.last.end_of_day
    OrderLine.joins(order: :customer)
             .includes(:price, order: :customer)
             .where(orders: { kind: "normal", status: "submitted", created_at: Date.new(1970, 1, 1)..cutoff })
             .order("orders.po_number", "order_lines.line_no").find_each do |line|
      open = line.open_qty
      next if open <= 0

      rate = rate_for(cutoff.beginning_of_month, line.order.currency)
      chip = (open * (line.base_price || 0)).round(2)
      v1 = (open * (line.v1_price || 0)).round(2)
      v2 = (open * (line.v2_price || 0)).round(2)
      @backlog_rows << Row.new(cutoff.to_date, line.display_no,
                               cust_name(line.order.customer), line.order.currency,
                               line.generic_part_no, line.order_item&.group, open,
                               line.base_price || 0, line.v1_price || 0, line.v2_price || 0,
                               chip, v1, v2, line.unit_price * open, rate,
                               (line.unit_price * open * rate).round(2), line.version,
                               line.price&.price_number)
    end
  end

  def build_shipments
    # 成分单价与月度工作簿出库单同口径：分配加权的 芯片/声码1/声码2（本币）
    ShipmentLine.joins(shipment: { sales_order: :customer })
                .includes(shipment: { sales_order: :customer },
                          production_line: { item: [], production_allocations: { order_line: :order } })
                .where(shipments: { shipped_at: @range })
                .order("shipments.shipped_at").find_each do |sl|
      pl = sl.production_line
      # 币别：分配订单快照优先（单价口径来源），无分配回退客户现币别（旧数据快照失真时仍按客户口径）
      currency = pl&.production_allocations&.first&.order_line&.order&.currency ||
                 sl.shipment.sales_order.customer.currency.presence || "RMB"
      rate = rate_for(sl.shipment.shipped_at.beginning_of_month, currency)
      allocs = pl&.production_allocations || []
      total_alloc = allocs.sum(&:quantity).to_f
      if total_alloc.positive?
        chip_p = allocs.sum { |a| a.quantity * (a.order_line&.base_price || 0).to_f } / total_alloc
        v1_p = allocs.sum { |a| a.quantity * (a.order_line&.v1_price || 0).to_f } / total_alloc
        v2_p = allocs.sum { |a| a.quantity * (a.order_line&.v2_price || 0).to_f } / total_alloc
      else
        chip_p = v1_p = v2_p = 0.0
      end
      qty = sl.quantity
      unit = (pl&.unit_price || 0).round(2)
      @shipment_rows << Row.new(sl.shipment.shipped_at.to_date, sl.shipment.sales_order.serial_number,
                                cust_name(sl.shipment.sales_order.customer), currency,
                                pl&.part_number, pl&.item&.group, qty,
                                chip_p.round(2), v1_p.round(2), v2_p.round(2),
                                (qty * chip_p).round(2), (qty * v1_p).round(2), (qty * v2_p).round(2),
                                (qty * unit).round(2), rate,
                                (qty * unit * rate).round(2), sl.shipment.tracking_no, nil)
    end
  end

  # 价格依据段：对账月生效中的报价（approved/active 且有效期与当月有交集），
  # 标记 本月新生效（effective_from 在当月）/ 本月失效（expired_at 在当月）——
  # 内部对账底稿的价格主数据页：核对交易单价「为什么是这个」的依据
  def build_prices
    Price.where(status: %w[approved active])
         .where("(effective_from IS NULL OR effective_from <= ?) AND (expired_at IS NULL OR expired_at >= ?)",
                @range.last, @range.begin)
         .includes(:customer).order("customers.name_zh", "customers.name", :part_number, :condition)
         .find_each do |p|
      flag = if p.effective_from && p.effective_from.between?(@range.begin.to_date, @range.last.to_date)
               "本月新生效"
             elsif p.expired_at && p.expired_at.between?(@range.begin.to_date, @range.last.to_date)
               "本月失效"
             else
               ""
             end
      @price_rows << PriceRow.new(p.price_number, cust_name(p.customer), p.part_number,
                                  p.condition, p.base_price, p.v1_price, p.v2_price, p.price,
                                  p.effective_from, p.expired_at, p.currency.presence || "RMB",
                                  p.status, flag)
    end
  end

  # 排产核对段：当月下发的已提交六联单行 + 分配台账明细（订单行×数量 串接）。
  # 用途：与 Excel 六联单表的 FIFO 分配公式结果（订单1~5/分配量1~5）逐行对照
  def build_allocations
    SalesOrder.includes(:customer, production_lines: { item: [], production_allocations: { order_line: :order } })
              .where(status: "submitted", created_at: @range)
              .order("sales_orders.created_at", "sales_orders.serial_number", "production_lines.id")
              .find_each do |so|
      so.production_lines.each do |pl|
        allocs = pl.production_allocations.sort_by { |a| a.order_line&.display_no.to_s }
        detail = allocs.map { |a| "#{a.order_line&.display_no}×#{a.quantity}" }.join("；")
        @allocation_rows << AllocRow.new(so.created_at.to_date, so.serial_number,
                                         cust_name(so.customer),
                                         pl.item&.partNo || pl.part_number,
                                         pl.quantity, pl.version, detail,
                                         allocs.sum(&:quantity), pl.shipped_qty, so.status)
      end
    end
  end

  # 段合计（本币金额跨币别无意义，合计一律折 RMB）
  def totals_for(rows)
    {
      qty: rows.sum(&:quantity),
      chip_rmb: rows.sum { |r| r.chip_amt * r.rate }.round(2),
      v1_rmb: rows.sum { |r| r.v1_amt * r.rate }.round(2),
      v2_rmb: rows.sum { |r| r.v2_amt * r.rate }.round(2),
      amount_rmb: rows.sum(&:amount_rmb).round(2)
    }
  end

  # 按币别分组合计：{ "RMB" => 合计, "USD" => 合计 }，本币口径 + 折 RMB 双列（视图/导出分节小计用）
  def totals_by_currency(rows)
    rows.group_by(&:currency).transform_values do |group|
      totals_for(group).merge(
        chip: group.sum(&:chip_amt).round(2),
        v1: group.sum(&:v1_amt).round(2),
        v2: group.sum(&:v2_amt).round(2),
        amount: group.sum(&:amount).round(2)
      )
    end
  end

  def order_totals = totals_for(order_rows)
  def shipment_totals = totals_for(shipment_rows)
  def backlog_totals = totals_for(backlog_rows)

  # 排产核对段合计：Σ数量 / Σ分配 / Σ发货（三者可一眼校验 Σ分配=数量）
  def allocation_totals
    {
      qty: allocation_rows.sum(&:quantity),
      alloc: allocation_rows.sum(&:alloc_total),
      shipped: allocation_rows.sum(&:shipped_qty)
    }
  end

  # 价格依据段合计：条数 / 本月新生效 / 本月失效
  def price_totals
    {
      count: price_rows.size,
      new: price_rows.count { |r| r.flag == "本月新生效" },
      expired: price_rows.count { |r| r.flag == "本月失效" }
    }
  end

  # 币别列/附加列已去除（视图按币别拆段显示），日期移首列；报价号 = 单价来源追溯（第 4 列）
  HEADERS = %w[日期 客户 单据号 报价号 产品 产品大类 数量
               芯片单价 声码1单价 声码2单价
               芯片金额 声码1金额 声码2金额 金额合计 汇率 折RMB合计].freeze

  # 价格依据段表头与行
  PRICE_HEADERS = %w[报价号 客户 通用型号 订单量档位 芯片 声码1 声码2 总单价
                     生效日期 失效日期 币别 状态 备注].freeze

  def to_price_rows
    price_rows.map { |r| [r.price_no, r.customer, r.part, r.condition, r.chip, r.v1, r.v2,
                          r.price, r.effective_from, r.expired_at, r.currency, r.status, r.flag] }
  end

  def to_rows(rows)
    rows.map { |r| [r.date, r.customer, r.doc_no, r.price_no, r.part, r.group, r.quantity,
                    r.chip_price, r.v1_price, r.v2_price,
                    r.chip_amt, r.v1_amt, r.v2_amt, r.amount, r.rate, r.amount_rmb] }
  end

  # 排产核对段表头与行
  ALLOC_HEADERS = %w[下单日期 六联单号 客户 产品 数量 版本 分配明细 Σ分配 已发货 状态].freeze

  def to_allocation_rows
    allocation_rows.map { |r| [r.date, r.serial, r.customer, r.part, r.quantity,
                               r.version, r.alloc_detail, r.alloc_total, r.shipped_qty, r.status] }
  end

  # 区间汇总工作簿：每月一个 sheet，纵向四段（订单核对/出货核对/未交订单/排产核对），
  # 段标题 + 表头 + 数据 + 合计；跨度上限 24 个月（防误操作）
  def self.summary_xlsx(from, to)
    raise "区间跨度过大（限 24 个月）" if (to.year * 12 + to.month) - (from.year * 12 + from.month) >= 24

    require "caxlsx"
    package = Axlsx::Package.new
    wb = package.workbook
    sec_style = wb.styles.add_style(b: true, font_color: "1F4E79")
    head_style = wb.styles.add_style(b: true, bg_color: "D9E1F2")
    bold_style = wb.styles.add_style(b: true)

    (from..to).map(&:beginning_of_month).uniq.each do |m|
      st = new(m)
      wb.add_worksheet(name: m.strftime("%Y-%m")) do |ws|
        ws.add_row(["#{m.strftime('%Y-%m')} 内部对账单"], style: sec_style)
        { "订单核对" => st.order_rows, "出货核对" => st.shipment_rows,
          "未交订单（截至月末）" => st.backlog_rows }.each do |title, rows|
          ws.add_row([])
          ws.add_row(["【#{title}】"], style: sec_style)
          ws.add_row(HEADERS, style: head_style)
          st.to_rows(rows).each { |r| ws.add_row(r) }
          t = st.totals_for(rows)
          ws.add_row(["合计", "", "", "", t[:qty], "", "", "", "", "", "", "", "", "", t[:amount_rmb], ""], style: bold_style)
        end
        ws.add_row([])
        ws.add_row(["【排产核对】"], style: sec_style)
        ws.add_row(ALLOC_HEADERS, style: head_style)
        st.to_allocation_rows.each { |r| ws.add_row(r) }
        at = st.allocation_totals
        ws.add_row(["合计", "", "", "", at[:qty], "", "", at[:alloc], at[:shipped], ""], style: bold_style)
        pt = st.price_totals
        ws.add_row([])
        ws.add_row(["【价格依据】生效中 #{pt[:count]} 条（本月新生效 #{pt[:new]} / 本月失效 #{pt[:expired]}），明细见单月对账单「价格依据」sheet"], style: sec_style)
      end
    end
    package.to_stream.read
  end

  private

  def sort_rows!
    key = ->(r) { [r.currency, r.customer, r.date, r.doc_no] }
    @order_rows.sort_by!(&key)
    @shipment_rows.sort_by!(&key)
    @backlog_rows.sort_by!(&key)
  end

  def cust_name(customer)
    customer.name_zh.presence || customer.name
  end

  def rate_for(month_date, currency)
    return 1 if currency.blank? || currency == "RMB"

    ExchangeRate.rate_for(month_date, currency) || 1
  end
end
