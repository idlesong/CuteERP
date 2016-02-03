class ApplicationController < ActionController::Base
  before_filter :authorize
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
    
    helper_method :current_user

    helper_method :current_customer

  protected
    def authorize
    	unless User.find_by_id(session[:user_id])
    		redirect_to login_url, :notice => "Please log in"
    	end
    end
end
