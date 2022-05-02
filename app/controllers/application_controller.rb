class ApplicationController < ActionController::Base
  # before_filter :authorize
  protect_from_forgery

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
      session[:cart_currency] = 'RMB' if session[:cart_currency].nil?
      session[:cart_currency]
    end

    def monthly_exchange_rate
      this_month_start = DateTime.now.beginning_of_month()
      # @exchange_rate_setting = Setting.where("name = ? AND updated_at > ?", 'exchange rate', this_month_start).first
      # @exchange_rate_setting = Setting.where(:name => 'exchange rate').first
      @exchange_rate_setting = current_user.settings(:exchange_rate).name_zh

      if not @exchange_rate_setting.nil?
        if @exchange_rate_setting.value.to_f > 0
          session[:exchange_rate] = @exchange_rate_setting.value.to_f
        end
      else
        session[:exchange_rate] = 1
      end
    end

    def current_cart_order
      if(session[:cart_order_type] == "SalesOrder")
        # SalesOrder.find(session[:cart_order_id])
        session[:cart_order_type]
      else
        # Order.find(session[:cart_order_id])
        session[:cart_order_type]
      end
    end

    def current_customer
      Customer.find(session[:customer_id])
    rescue ActiveRecord::RecordNotFound
      customer = Customer.first
      session[:customer_id] = customer.id
      customer
    end

    def current_user
      @current_user ||= User.find(session[:user_id]) if session[:user_id]
    end

    helper_method :current_cart_currency
    helper_method :monthly_exchange_rate
    helper_method :current_customer
    helper_method :current_user

  protected
    def authorize
    	# unless User.find_by_id(session[:user_id])
    	# 	redirect_to login_url, :notice => "Please log in"
    	# end
    end
end
