# 月度对账单（第二阶段 2.3）：客户 × 月份，页面 + 导出；区间汇总（每月一个 sheet 纵向四段）
require "caxlsx"

class StatementsController < ApplicationController
  # GET /statements?customer_id=&month= —— customer_id=all 显示全部客户（币别→客户→大类排序）
  def show
    @month = parse_month(params[:month]) || Date.current.beginning_of_month
    if params[:customer_id] == "all"
      @internal = InternalMonthlyStatement.new(@month)
    elsif params[:customer_id].present?
      @customer = Customer.find(params[:customer_id])
      @statement = MonthlyStatement.new(@customer, @month)
    else
      @customers = Customer.order(:name)
    end
  end

  # GET /statements/export?customer_id=&month= —— CSV 导出
  def export
    customer = Customer.find(params[:customer_id])
    month = parse_month(params[:month]) || Date.current.beginning_of_month
    st = MonthlyStatement.new(customer, month)

    row_to_a = lambda { |seg, r| [seg, r.date, r.doc_no, r.part, r.quantity, r.unit_price, r.amount, r.amount_rmb, r.extra] }
    xlsx = Xlsx.generate([
      { name: "订单核对", headers: %w[日期 单据号 型号 数量 单价 金额 金额折RMB 版本],
        rows: st.order_rows.map { |r| row_to_a.call("订单核对", r)[1..] } },
      { name: "出货核对", headers: %w[出库日期 六联单号 型号 数量 单价 金额 金额折RMB 快递号],
        rows: st.shipment_rows.map { |r| row_to_a.call("出货核对", r)[1..] } },
      { name: "未交订单", headers: %w[截至日期 订单行 型号 未交数量 单价 未交金额 折RMB 版本],
        rows: st.backlog_rows.map { |r| row_to_a.call("未交订单", r)[1..] } }
    ])
    filename = "对账单_#{customer.name_zh.presence || customer.name}_#{month.strftime('%Y%m')}.xlsx"
    send_data xlsx, filename: filename, type: "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet"
  end

  # GET /statements/export_internal?month= —— 全部客户内部对账单（币别→客户→日期，成分拆分，按币别小计）
  def export_internal
    month = parse_month(params[:month]) || Date.current.beginning_of_month
    st = InternalMonthlyStatement.new(month)

    rows_with_totals = lambda { |rows|
      result = []
      st.totals_by_currency(rows).each do |cur, t|
        result += st.to_rows(rows.select { |r| r.currency == cur })
        result << ["", "小计 #{cur} 客户", "", "", "", t[:qty], "", "", "",
                   t[:chip], t[:v1], t[:v2], t[:amount], "", t[:amount_rmb], ""]
      end
      t = st.totals_for(rows)
      result << ["", "合计(折RMB)", "", "", "", t[:qty], "", "", "",
                 t[:chip_rmb], t[:v1_rmb], t[:v2_rmb], "", "", t[:amount_rmb], ""]
      result
    }

    xlsx = Xlsx.generate([
      # 前两段按财务对账 Excel 列序（含空列占位），末尾合计行；页面口径见 InternalMonthlyStatement
      { name: "客户订单", headers: InternalMonthlyStatement::ORDER_EXPORT_HEADERS,
        rows: st.to_order_export_rows + [st.order_export_total_row] },
      { name: "销售发货", headers: InternalMonthlyStatement::SHIPMENT_EXPORT_HEADERS,
        rows: st.to_shipment_export_rows + [st.shipment_export_total_row] },
      { name: "未交订单", headers: InternalMonthlyStatement::HEADERS,
        rows: rows_with_totals.call(st.backlog_rows) },
      { name: "排产核对", headers: InternalMonthlyStatement::ALLOC_HEADERS,
        rows: st.to_allocation_rows },
      { name: "价格依据", headers: InternalMonthlyStatement::PRICE_HEADERS,
        rows: st.to_price_rows }
    ])
    send_data xlsx,
              filename: "内部对账单_全部客户_#{month.strftime('%Y%m')}.xlsx",
              type: "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet"
  end

  # GET /statements/export_summary?from=&to= —— 区间汇总：每月一个 sheet（四段纵向），合成一个工作簿
  def export_summary
    from = parse_month(params[:from]) || Date.current.beginning_of_month
    to = parse_month(params[:to]) || from
    to = from if to < from

    xlsx = InternalMonthlyStatement.summary_xlsx(from, to)
    send_data xlsx,
              filename: "内部对账单_汇总_#{from.strftime('%Y%m')}-#{to.strftime('%Y%m')}.xlsx",
              type: "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet"
  rescue StandardError => e
    redirect_to statement_path, alert: "汇总导出失败：#{e.message}"
  end

  private

  def parse_month(raw)
    Date.strptime(raw.to_s, "%Y-%m").beginning_of_month
  rescue ArgumentError, TypeError
    nil
  end
end
