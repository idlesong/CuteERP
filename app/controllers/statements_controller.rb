# 月度对账单（第二阶段 2.3）：客户 × 月份，页面 + 导出
class StatementsController < ApplicationController
  # GET /statements?customer_id=&month=
  def show
    @customer = Customer.find(params[:customer_id]) if params[:customer_id].present?
    @month = parse_month(params[:month]) || Date.current.beginning_of_month

    if @customer
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

  # GET /statements/export_internal?month= —— 全部客户内部对账单（币别→客户→产品大类，成分拆分）
  def export_internal
    month = parse_month(params[:month]) || Date.current.beginning_of_month
    st = InternalMonthlyStatement.new(month)

    totals_row = lambda { |t| ["合计(折RMB)", "", "", "", "", "", t[:qty], "", "", "",
                               t[:chip_rmb], t[:v1_rmb], t[:v2_rmb], "", "", t[:amount_rmb], ""] }
    xlsx = Xlsx.generate([
      { name: "订单核对", headers: InternalMonthlyStatement::HEADERS,
        rows: st.to_rows(st.order_rows) + [totals_row.call(st.order_totals)] },
      { name: "出货核对", headers: InternalMonthlyStatement::HEADERS,
        rows: st.to_rows(st.shipment_rows) + [totals_row.call(st.shipment_totals)] },
      { name: "未交订单", headers: InternalMonthlyStatement::HEADERS,
        rows: st.to_rows(st.backlog_rows) + [totals_row.call(st.backlog_totals)] }
    ])
    send_data xlsx,
              filename: "内部对账单_全部客户_#{month.strftime('%Y%m')}.xlsx",
              type: "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet"
  end

  private

  def parse_month(raw)
    Date.strptime(raw.to_s, "%Y-%m").beginning_of_month
  rescue ArgumentError, TypeError
    nil
  end
end
