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

    csv = CSV.generate(write_headers: true, headers: %w[段 日期 单据号 型号 数量 单价 金额 金额折RMB 附加]) do |csv|
      st.order_rows.each { |r| csv << ["订单核对", r.date, r.doc_no, r.part, r.quantity, r.unit_price, r.amount, r.amount_rmb, r.extra] }
      st.shipment_rows.each { |r| csv << ["出货核对", r.date, r.doc_no, r.part, r.quantity, r.unit_price, r.amount, r.amount_rmb, r.extra] }
      st.backlog_rows.each { |r| csv << ["未交订单", r.date, r.doc_no, r.part, r.quantity, r.unit_price, r.amount, r.amount_rmb, r.extra] }
    end
    filename = "对账单_#{customer.name_zh.presence || customer.name}_#{month.strftime('%Y%m')}.csv"
    send_data csv, filename: filename, type: "text/csv; charset=utf-8"
  end

  private

  def parse_month(raw)
    Date.strptime(raw.to_s, "%Y-%m").beginning_of_month
  rescue ArgumentError, TypeError
    nil
  end
end
