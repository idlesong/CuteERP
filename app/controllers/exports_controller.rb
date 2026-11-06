# 导出/导入中心（第二阶段：月度工作簿 + 批量导入 + 对账单）
class ExportsController < ApplicationController
  # GET /exports —— 月份选择页
  def index
    @month = parse_month(params[:month]) || Date.current.beginning_of_month
  end

  # GET /exports/monthly?month=2026-10 —— 下载月度工作簿
  def monthly
    month = parse_month(params[:month]) || Date.current.beginning_of_month
    workbook = MonthlyWorkbook.generate(month)
    filename = "cute_erp_#{month.strftime('%Y%m')}.xlsx"
    send_data workbook, filename: filename, type: "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet"
  end

  # GET /exports/all —— 全量导出（所有时间段数据，不限月份）
  def export_all
    workbook = MonthlyWorkbook.generate(nil)
    send_data workbook,
              filename: "cute_erp_all_#{Date.current.strftime('%Y%m%d')}.xlsx",
              type: "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet"
  end

  private

  def parse_month(raw)
    return nil if raw.blank?

    Date.strptime(raw, "%Y-%m").beginning_of_month
  rescue ArgumentError
    nil
  end
end
