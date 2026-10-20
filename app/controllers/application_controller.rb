class ApplicationController < ActionController::Base
  protect_from_forgery with: :exception

  before_action :authorize

  private

  def monthly_exchange_rate
    rate = ExchangeRate.rate_for(Date.current, "USD")
    rate ||= legacy_monthly_rate
    session[:exchange_rate] = rate.to_f.positive? ? rate.to_f : 1
  end

  # 旧机制：汇率存在 User settings（exchange_rate.current_month），仅作回退
  def legacy_monthly_rate
    value = current_user&.settings(:exchange_rate)&.value
    value = value["current_month"] if value.is_a?(Hash)
    value.to_f
  rescue StandardError
    0
  end

  def current_customer
    Customer.find(session[:customer_id])
  rescue ActiveRecord::RecordNotFound
    customer = Customer.first
    raise ActiveRecord::RecordNotFound if customer.nil?

    session[:customer_id] = customer.id
    customer
  end

  def current_user
    return @current_user if defined?(@current_user)

    @current_user = User.find_by(id: session[:user_id]) if session[:user_id]
    session.delete(:user_id) if @current_user.nil? # 清理失效会话（用户被删除等）
    @current_user
  end

  def current_path_action
    session[:current_path_action] = "new" if session[:current_path_action].nil?
    session[:current_path_action]
  end

  # 导入批次 → notice 文案（导入中心/订单页共用）
  def import_report(import)
    st = import.stats
    msg = "导入完成：新建 #{st['created'] || st[:created]}，更新 #{st['updated'] || st[:updated]}，跳过 #{st['skipped'] || st[:skipped]}"
    errors = st["errors"] || st[:errors] || []
    warnings = st["warnings"] || st[:warnings] || []
    msg += "；错误：#{errors.join('；')}" if errors.any?
    msg += "；警告：#{warnings.join('；')}" if warnings.any?
    msg
  end
  helper_method :import_report

  # 两阶段导入：导入前强制预检（事务回滚干跑，不落数据）。
  # 有错误 → 阻止导入，生成标注文件并把下载入口放到导入中心；通过 → 返回 true
  def import_precheck!(importer, month: nil)
    result = ImportChecker.run(importer, params[:file], month: month)
    return true unless ImportChecker.blocked?(result)

    session[:check_token] = ImportChecker.store_annotated(importer, params[:file], result)
    n = result.errors.values.flatten.size
    redirect_to imports_path,
                alert: "导入已阻止：发现 #{n} 处错误，请下载「错误标注文件」修正后重新导入（警告 #{result.warnings.values.flatten.size} 条不阻断）"
    false
  end

  helper_method :monthly_exchange_rate
  helper_method :current_customer
  helper_method :current_user
  helper_method :current_path_action

  def authorize
    unless User.find_by_id(session[:user_id])
      redirect_to login_url, notice: "Please log in"
    end
  end
end
