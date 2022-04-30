class QuotationsController < ApplicationController
  before_action :set_quotation, only: [:show, :edit, :update, :destroy]

  # GET /quotations
  def index
    @quotations = Quotation.all
  end

  # GET /quotations/1
  def show
    @quotation = Quotation.find(params[:id])

    respond_to do |format|
      format.html # show.html.erb
      format.json { render json: @contact }
    end
  end

  # GET /quotations/new
  def new
    # @quotation = Quotation.new

    # clear cart and destroy associated line_items, when customer switched
    if (params[:customer_id] && (params[:customer_id] != current_customer.id))
      session[:customer_id] = params[:customer_id]
      # current_cart.line_items.clear
    end

    @customers = Customer.all
    @customer = current_customer

    @quotation = Quotation.new
    @quotation.customer_id = @customer.id
    @unquotated_prices = Price.where(customer_id: @customer.id, quotation_id: nil)
    # @quotation.prices = Price.where(customer_id: @customer.id)
  end

  # GET /quotations/1/edit
  def edit
    @quotation = Quotation.find(params[:id])

    @customers = Customer.all
    @customer = @quotation.customer

    @unquotated_prices = Price.where(customer_id: @customer.id, quotation_id: nil)
    @unquotated_prices += Price.where(quotation_id: @quotation.id)
  end

  # POST /quotations
  def create
    @quotation = Quotation.new(customer_id: quotation_params['customer_id'])
    @quotation.quotation_number = quotation_params['quotation_number']
    # logger.debug "=====quotation.number== #{@quotation.quotation_number}"    

    if @quotation.save
      #  @prices = Price.where("id = ?", quotation_params[:prices]) #Not work:?
      @prices = Price.where(id: quotation_params[:prices])
      @prices.update_all(quotation_id: @quotation.id)

      redirect_to @quotation, notice: 'Quotation was successfully created.'
    else
      render :new
    end
  end

  # PATCH/PUT /quotations/1
  def update
    @quotation = Quotation.new(customer_id: quotation_params['customer_id'])
    @quotation.quotation_number = quotation_params['quotation_number']

    if @quotation.save
      @prices = Price.where(id: quotation_params[:prices])
      @prices.update_all(quotation_id: @quotation.id)      
      redirect_to @quotation, notice: 'Quotation was successfully updated.'
    else
      render :edit
    end
  end

  # DELETE /quotations/1
  def destroy
    @quotation.destroy
    redirect_to quotations_url, notice: 'Quotation was successfully destroyed.'
  end

  private
    # Use callbacks to share common setup or constraints between actions.
    def set_quotation
      @quotation = Quotation.find(params[:id])
    end

    # Only allow a trusted parameter "white list" through.
    def quotation_params
      params.require(:quotation).permit(:quotation_number, :remark, :customer_id, :prices, prices: []) 
                # prices_attributes:[:id, :quotation_id, :item_id, :price, :condition, :_destroy])
    end
end
