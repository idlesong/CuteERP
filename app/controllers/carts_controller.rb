class CartsController < ApplicationController
  # legacy note: the old app skipped authorization for create/update only
  # (its skip list contained a typo'd `:destory` that never matched).
  skip_before_action :authorize, only: [:create, :update]

  # GET /carts
  def index
    @carts = Cart.all

    respond_to do |format|
      format.html
      format.json { render json: @carts }
    end
  end

  # GET /carts/1
  def show
    begin
      @cart = Cart.find(params[:id])
    rescue ActiveRecord::RecordNotFound
      logger.error "Attempt to access invalid cart #{params[:id]}"
      redirect_to inventory_url, notice: "Invalid cart"
    else
      respond_to do |format|
        format.html
        format.json { render json: @cart }
      end
    end
  end

  # GET /carts/new
  def new
    @cart = Cart.new

    respond_to do |format|
      format.html
      format.json { render json: @cart }
    end
  end

  # GET /carts/1/edit
  def edit
    @cart = Cart.find(params[:id])
  end

  # POST /carts
  def create
    @cart = Cart.new

    respond_to do |format|
      if @cart.save
        format.html { redirect_to @cart, notice: "Cart was successfully created." }
        format.json { render json: @cart, status: :created, location: @cart }
      else
        format.html { render action: "new" }
        format.json { render json: @cart.errors, status: :unprocessable_entity }
      end
    end
  end

  # PATCH/PUT /carts/1
  def update
    @cart = Cart.find(params[:id])

    respond_to do |format|
      if @cart.update({})
        format.html { redirect_to @cart, notice: "Cart was successfully updated." }
        format.json { head :no_content }
      else
        format.html { render action: "edit" }
        format.json { render json: @cart.errors, status: :unprocessable_entity }
      end
    end
  end

  # DELETE /carts/1
  def destroy
    @cart = current_cart
    @cart.destroy
    session[:cart_id] = nil

    @cart = current_issue_cart
    @cart.destroy
    session[:issue_cart_id] = nil

    respond_to do |format|
      format.html { redirect_to orders_url }
      format.json { head :no_content }
    end
  end
end
