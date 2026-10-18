# 导入中心（第二阶段 2.2）：客户订单 / 六联单 批量导入 + 批次历史
class ImportsController < ApplicationController
  # GET /imports
  def index
    @imports = Import.order(created_at: :desc).limit(50)
    @month = params[:month].presence || Date.current.strftime("%Y-%m")
  end

  # POST /imports/customer_orders
  def import_customer_orders
    return redirect_to imports_path, alert: "请选择文件" if params[:file].blank?

    import = CustomerOrdersImport.call(params[:file], imported_by: current_user, month: parse_month(params[:month]))
    redirect_to imports_path, notice: import_report(import)
  rescue StandardError => e
    redirect_to imports_path, alert: "导入失败：#{e.message}"
  end

  # POST /imports/prices —— 报价导入（对账模板「价格」表）
  def import_prices
    return redirect_to imports_path, alert: "请选择文件" if params[:file].blank?

    result = Price.import(params[:file], imported_by: current_user)
    notice = "报价导入完成：新增 #{result[:created]} 条，更新 #{result[:updated]} 条"
    notice += "；警告：#{result[:warnings].join('；')}" if result[:warnings].any?
    redirect_to imports_path, notice: notice
  rescue StandardError => e
    redirect_to imports_path, alert: "导入失败：#{e.message}"
  end

  # POST /imports/sales_orders
  def import_sales_orders
    return redirect_to imports_path, alert: "请选择文件" if params[:file].blank?

    import = SalesOrdersImport.call(params[:file], imported_by: current_user, month: parse_month(params[:month]))
    redirect_to imports_path, notice: import_report(import)
  rescue StandardError => e
    redirect_to imports_path, alert: "导入失败：#{e.message}"
  end

  private

  def parse_month(raw)
    Date.strptime(raw.to_s, "%Y-%m").beginning_of_month
  rescue ArgumentError, TypeError
    nil
  end
end
