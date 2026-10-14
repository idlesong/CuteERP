class ApplicationController < ActionController::Base
  protect_from_forgery with: :exception

  before_action :authorize

  private

  def current_cart
    Cart.find(session[:cart_id])
  rescue ActiveRecord::RecordNotFound
    cart = Cart.create
    session[:cart_id] = cart.id
    cart
  end

  def current_issue_cart
    Cart.find(session[:issue_cart_id])
  rescue ActiveRecord::RecordNotFound
    cart = Cart.create
    session[:issue_cart_id] = cart.id
    cart
  end

  def current_cart_currency
    session[:cart_currency] = "RMB" if session[:cart_currency].nil?
    session[:cart_currency]
  end

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

  helper_method :current_cart_currency
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
