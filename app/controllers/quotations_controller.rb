class QuotationsController < ApplicationController
  before_action :set_quotation, only: [:show, :edit, :update, :destroy]

  # GET /quotations
  def index
    @quotations = Quotation.all
  end

  # GET /quotations/1
  def show
    respond_to do |format|
      format.html
      format.json { render json: @quotation }
    end
  end

  # GET /quotations/new
  def new
    # clear cart and destroy associated line_items, when customer switched
    if params[:customer_id] && (params[:customer_id] != current_customer.id.to_s)
      session[:customer_id] = params[:customer_id]
    end

    @customers = Customer.all
    @customer = current_customer

    @quotation = Quotation.new
    @quotation.customer_id = @customer.id
    @unquotated_prices = Price.where(customer_id: @customer.id, quotation_id: nil)
  end

  # GET /quotations/1/edit
  def edit
    @customers = Customer.all
    @customer = @quotation.customer

    @unquotated_prices = Price.where(customer_id: @customer.id, quotation_id: nil)
    @unquotated_prices += Price.where(quotation_id: @quotation.id)
  end

  # POST /quotations
  def create
    @quotation = Quotation.new(customer_id: quotation_params["customer_id"])
    @quotation.quotation_number = quotation_params["quotation_number"]
    @quotation.remark = quotation_params["remark"]

    if @quotation.save
      @prices = Price.where(id: quotation_params[:prices])
      @prices.update_all(quotation_id: @quotation.id)

      redirect_to @quotation, notice: "Quotation was successfully created."
    else
      render :new
    end
  end

  # PATCH/PUT /quotations/1
  def update
    @quotation.customer_id = quotation_params["customer_id"]
    @quotation.quotation_number = quotation_params["quotation_number"]
    @quotation.remark = quotation_params["remark"]

    if @quotation.save
      @prices = Price.where(id: quotation_params[:prices])
      @prices.update_all(quotation_id: @quotation.id)
      redirect_to @quotation, notice: "Quotation was successfully updated."
    else
      render :edit
    end
  end

  # DELETE /quotations/1
  def destroy
    @quotation.destroy
    redirect_to quotations_url, notice: "Quotation was successfully destroyed."
  end

  private

  def set_quotation
    @quotation = Quotation.find(params[:id])
  end

  def quotation_params
    params.require(:quotation).permit(:quotation_number, :remark, :customer_id, prices: [])
  end
end
