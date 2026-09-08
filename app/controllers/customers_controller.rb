class CustomersController < ApplicationController
  before_action :set_customer, only: [:show, :edit, :update, :destroy]

  # GET /customers
  def index
    @customers = Customer.all

    respond_to do |format|
      format.html
      format.json { render json: CustomersDatatable.new(view_context) }

      format.csv { send_data @customers.export_to_csv }
      format.xls { send_data @customers.export_to_csv(col_sep: "\t") }
    end
  end

  # GET /customers/1
  def show
    @contacts = Contact.where("customer_id = ?", @customer.id)
    @orders = Order.where("customer_id = ?", @customer.id)
    @sales_orders = SalesOrder.where("customer_id = ?", @customer.id)
    @opportunities = Opportunity.where("customer_id = ?", @customer.id).order("created_at")
    @oppostatuses = Oppostatus.all
    @users = User.all
    @prices = Price.where("customer_id = ?", @customer.id).where.not(status: "archived")

    # add session id to customer id when show a customer
    session[:customer_id] = @customer.id

    respond_to do |format|
      format.html
      format.js
    end
  end

  # GET /customers/new
  def new
    @customer = Customer.new

    @disties = Customer.where.not(sales_type: "OEM")
    respond_to do |format|
      if params[:simplify] == "yes"
        format.html { render "new_simplify" }
        format.js
      else
        format.html
        format.js
      end
    end
  end

  # GET /customers/1/edit
  def edit
    @disties = Customer.where.not(sales_type: "OEM")
    @disties = Customer.none if @disties.nil?
  end

  # POST /customers
  def create
    @customer = Customer.new(customer_params)

    respond_to do |format|
      if @customer.save
        format.html { redirect_to @customer, notice: "Customer was successfully created." }
        format.json { render json: @customer, status: :created, location: @customer }
      else
        format.html { render action: "new" }
        format.json { render json: @customer.errors, status: :unprocessable_entity }
      end
    end
  end

  # PATCH/PUT /customers/1
  def update
    respond_to do |format|
      if @customer.update(customer_params)
        format.html { redirect_to @customer, notice: "Customer was successfully updated." }
        format.json { head :no_content }
      else
        format.html { render action: "edit" }
        format.json { render json: @customer.errors, status: :unprocessable_entity }
      end
    end
  end

  # DELETE /customers/1
  def destroy
    respond_to do |format|
      if @customer.destroy
        format.html { redirect_to customers_url }
        format.json { head :no_content }
      else
        format.html { redirect_to customer_url(@customer), notice: "customer can't be destroyed" }
        format.json { render json: @customer.errors, status: :unprocessable_entity }
      end
    end
  end

  # POST /customers/import
  def import
    Customer.import(params[:file])
    redirect_to customers_url, notice: "Customers imported."
  end

  private

  def set_customer
    @customer = Customer.find(params[:id])
  end

  def customer_params
    params.require(:customer).permit(:address, :balance, :contact, :name, :full_name, :since,
                                     :telephone, :payment, :currency, :ship_contact, :ship_address,
                                     :ship_telephone, :credit, :sales_type, :disty_id, :territory)
  end
end
