# 导入中心（第二阶段 2.2）：客户订单 / 六联单 / 报价 / 出库单 批量导入 + 批次历史
# 两阶段导入：每个导入动作先经 ImportChecker 预检（事务回滚干跑），
# 有错误则阻止导入并生成「错误标注文件」供修正后重试；「检查」按钮仅预检不导入
class ImportsController < ApplicationController
  # GET /imports
  def index
    @imports = Import.order(created_at: :desc).limit(50)
    @month = params[:month].presence || Date.current.strftime("%Y-%m")
    @check_token = session[:check_token]
    if @check_token && ImportChecker.fetch_annotated(@check_token).nil?
      session.delete(:check_token) # 标注文件已过期（30 分钟）
      @check_token = nil
    end
  end

  # GET /imports/check_file/:token —— 下载错误标注文件
  def check_file
    path = ImportChecker.fetch_annotated(params[:token])
    return redirect_to imports_path, alert: "标注文件不存在或已过期（30 分钟），请重新检查" unless path

    send_file path, filename: "导入检查_错误标注.xlsx",
                    type: "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet"
  end

  # POST /imports/customer_orders
  def import_customer_orders
    return redirect_to imports_path, alert: "请选择文件" if params[:file].blank?
    return check_only(CustomerOrdersImport) if params[:commit] == "check"
    return unless import_precheck!(CustomerOrdersImport, month: parse_month(params[:month]))

    import = CustomerOrdersImport.call(params[:file], imported_by: current_user, month: parse_month(params[:month]))
    redirect_to imports_path, notice: import_report(import)
  rescue StandardError => e
    redirect_to imports_path, alert: "导入失败：#{e.message}"
  end

  # POST /imports/prices —— 报价导入（对账模板「价格」表）
  def import_prices
    return redirect_to imports_path, alert: "请选择文件" if params[:file].blank?
    return check_only(Price) if params[:commit] == "check"
    return unless import_precheck!(Price, month: parse_month(params[:month]))

    import = Price.import(params[:file], imported_by: current_user)
    redirect_to imports_path, notice: import_report(import)
  rescue StandardError => e
    redirect_to imports_path, alert: "导入失败：#{e.message}"
  end

  # POST /imports/sales_orders
  def import_sales_orders
    return redirect_to imports_path, alert: "请选择文件" if params[:file].blank?
    return check_only(SalesOrdersImport) if params[:commit] == "check"
    return unless import_precheck!(SalesOrdersImport, month: parse_month(params[:month]))

    import = SalesOrdersImport.call(params[:file], imported_by: current_user, month: parse_month(params[:month]))
    redirect_to imports_path, notice: import_report(import)
  rescue StandardError => e
    redirect_to imports_path, alert: "导入失败：#{e.message}"
  end

  # POST /imports/shipments —— 出库单导入（模板 = 月度工作簿「出库单」表）
  def import_shipments
    return redirect_to imports_path, alert: "请选择文件" if params[:file].blank?
    return check_only(ShipmentsImport) if params[:commit] == "check"
    return unless import_precheck!(ShipmentsImport, month: parse_month(params[:month]))

    import = ShipmentsImport.call(params[:file], imported_by: current_user, month: parse_month(params[:month]))
    redirect_to imports_path, notice: import_report(import)
  rescue StandardError => e
    redirect_to imports_path, alert: "导入失败：#{e.message}"
  end

  private

  # 「检查」按钮：仅预检不导入（与导入同端点，per-form CSRF token 才能匹配）
  def check_only(importer)
    result = ImportChecker.run(importer, params[:file], month: parse_month(params[:month]))
    if ImportChecker.blocked?(result)
      session[:check_token] = ImportChecker.store_annotated(importer, params[:file], result)
      redirect_to imports_path, alert: "检查发现 #{result.errors.values.flatten.size} 处错误（警告 #{result.warnings.values.flatten.size} 条），已生成错误标注文件，修正后才能导入"
    else
      n = result.warnings.values.flatten.size
      redirect_to imports_path, notice: "检查通过，可以导入#{n.positive? ? "（#{n} 条警告不阻断导入，导入后请复核）" : ""}"
    end
  rescue StandardError => e
    redirect_to imports_path, alert: "检查失败：#{e.message}"
  end

  def parse_month(raw)
    Date.strptime(raw.to_s, "%Y-%m").beginning_of_month
  rescue ArgumentError, TypeError
    nil
  end
end
