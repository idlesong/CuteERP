class CustomersController < ApplicationController
  # GET /customers
  # GET /customers.json
  def index
    @customers = Customer.all

    respond_to do |format|
      format.html # index.html.erb
      #format.json { render json: @customers }
      format.json { render json: CustomersDatatable.new(view_context) }
    end
  end

  # GET /customers/1
  # GET /customers/1.json
  def show
    @customer = Customer.find(params[:id])

    @contacts = Contact.where("customer_id = ?", @customer.id)
    @orders = Order.where("customer_id = ?", @customer.id)
    @sales_orders = SalesOrder.where("customer_id = ?", @customer.id)
    @opportunities = Opportunity.where("customer_id = ?", @customer.id).order("created_at")
    @oppostatuses = Oppostatus.all
    @users = User.all
    @prices = Price.where("customer_id = ?", @customer.id)

    #add session id to customer id when show a customer???
    session[:customer_id] = @customer.id

    respond_to do |format|
      format.html # show.html.erb
      format.js
    end
  end

  # GET /customers/new
  # GET /customers/new.json
  def new
    @customer = Customer.new

    respond_to do |format|
      if(params[:simplify] =='yes')
        format.html {render "new_simplify"}
        format.js
      else
        format.html # new.html.erb
        format.js
      end
    end
  end

  # GET /customers/1/edit
  def edit
    @customer = Customer.find(params[:id])
  end

  # POST /customers
  # POST /customers.json
  def create
    @customer = Customer.new(params[:customer])

    respond_to do |format|
      if @customer.save
        format.html { redirect_to @customer, notice: 'Customer was successfully created.' }
        format.json { render json: @customer, status: :created, location: @customer }
      else
        format.html { render action: "new" }
        format.json { render json: @customer.errors, status: :unprocessable_entity }
      end
    end
  end

  # PUT /customers/1
  # PUT /customers/1.json
  def update
    @customer = Customer.find(params[:id])

    respond_to do |format|
      if @customer.update_attributes(params[:customer])
        format.html { redirect_to @customer, notice: 'Customer was successfully updated.' }
        format.json { head :no_content }
      else
        format.html { render action: "edit" }
        format.json { render json: @customer.errors, status: :unprocessable_entity }
      end
    end
  end

  # DELETE /customers/1
  # DELETE /customers/1.json
  def destroy
    @customer = Customer.find(params[:id])
    @customer.destroy

    respond_to do |format|
      format.html { redirect_to customers_url }
      format.json { head :no_content }
    end
  end
end
