class OpportunitiesController < ApplicationController
  before_action :set_opportunity, only: [:show, :edit, :update, :destroy]

  # GET /opportunities
  def index
    @product_catalogs = Opportunity.select(:project_type).distinct

    if params[:catalog]
      @opportunities = Opportunity.where("project_type LIKE ?", "#{params[:catalog]}%")
    else
      @opportunities = Opportunity.all
    end

    @oppostatuses = Oppostatus.all
    @customers = Customer.all

    respond_to do |format|
      format.html
      format.json { render json: @opportunities }
    end
  end

  # GET /opportunities/1
  def show
    respond_to do |format|
      format.html
      format.json { render json: @opportunity }
    end
  end

  # GET /opportunities/new
  def new
    @opportunity = Opportunity.new(opportunity_params)

    respond_to do |format|
      format.html
      format.json { render json: @opportunity }
    end
  end

  # GET /opportunities/1/edit
  def edit
  end

  # POST /opportunities
  def create
    @opportunity = Opportunity.new(opportunity_params)

    respond_to do |format|
      if @opportunity.save
        format.html { redirect_to @opportunity, notice: "Opportunity was successfully created." }
        format.json { render json: @opportunity, status: :created, location: @opportunity }
      else
        format.html { render action: "new" }
        format.json { render json: @opportunity.errors, status: :unprocessable_entity }
      end
    end
  end

  # PATCH/PUT /opportunities/1
  def update
    respond_to do |format|
      if @opportunity.update(opportunity_params)
        format.html { redirect_to @opportunity, notice: "Opportunity was successfully updated." }
        format.json { head :no_content }
      else
        format.html { render action: "edit" }
        format.json { render json: @opportunity.errors, status: :unprocessable_entity }
      end
    end
  end

  # DELETE /opportunities/1
  def destroy
    @opportunity.destroy

    respond_to do |format|
      format.html { redirect_to opportunities_url }
      format.json { head :no_content }
    end
  end

  private

  def set_opportunity
    @opportunity = Opportunity.find(params[:id])
  end

  def opportunity_params
    params.fetch(:opportunity, {}).permit(:note, :priority, :project_type, :solution, :customer_id)
  end
end
