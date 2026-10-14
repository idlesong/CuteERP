class ExchangeRatesController < ApplicationController
  before_action :set_exchange_rate, only: :destroy

  # GET /exchange_rates
  def index
    @exchange_rates = ExchangeRate.order(month: :desc, currency: :asc)
    @exchange_rate = ExchangeRate.new
  end

  # POST /exchange_rates
  def create
    @exchange_rate = ExchangeRate.new(exchange_rate_params)

    if @exchange_rate.save
      redirect_to exchange_rates_url, notice: "汇率已保存。"
    else
      @exchange_rates = ExchangeRate.order(month: :desc, currency: :asc)
      render :index, status: :unprocessable_entity
    end
  end

  # DELETE /exchange_rates/1
  def destroy
    @exchange_rate.destroy
    redirect_to exchange_rates_url, notice: "已删除。"
  end

  private

  def set_exchange_rate
    @exchange_rate = ExchangeRate.find(params[:id])
  end

  def exchange_rate_params
    params.require(:exchange_rate).permit(:month, :currency, :rate)
  end
end
