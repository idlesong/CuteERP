# 导入中心（第二阶段 2.2）：客户订单 / 六联单 批量导入 + 批次历史
class ImportsController < ApplicationController
  # GET /imports
  def index
    @imports = Import.order(created_at: :desc).limit(50)
    @month = params[:month].presence || Date.current.strftime("%Y-%m")
  end

  # POST /imports/customer_orders
  def import_customer_orders
    unless params[:file].present?
      redirect_to imports_path, alert: "请选择文件" and return
    end
    import = CustomerOrdersImport.call(params[:file], imported_by: current_user, month: parse_month(params[:month]))
    redirect_to imports_path, notice: report(import)
  end

  # POST /imports/sales_orders
  def import_sales_orders
    unless params[:file].present?
      redirect_to imports_path, alert: "请选择文件" and return
    end
    import = SalesOrdersImport.call(params[:file], imported_by: current_user, month: parse_month(params[:month]))
    redirect_to imports_path, notice: report(import)
  end

  private

  def report(import)
    st = import.stats
    msg = "导入完成：新建 #{st['created'] || st[:created]}，更新 #{st['updated'] || st[:updated]}，跳过 #{st['skipped'] || st[:skipped]}"
    warnings = st["warnings"] || st[:warnings] || []
    msg += "；警告：#{warnings.join('；')}" if warnings.any?
    msg
  end

  def parse_month(raw)
    Date.strptime(raw.to_s, "%Y-%m").beginning_of_month
  rescue ArgumentError, TypeError
    nil
  end
end
