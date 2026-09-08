class OppostatusesController < ApplicationController
  before_action :set_oppostatus, only: [:show, :edit, :update, :destroy]

  # GET /oppostatuses
  def index
    @oppostatuses = Oppostatus.all

    respond_to do |format|
      format.html
      format.json { render json: @oppostatuses }
    end
  end

  # GET /oppostatuses/1
  def show
    respond_to do |format|
      format.html
      format.json { render json: @oppostatus }
    end
  end

  # GET /oppostatuses/new
  def new
    @oppostatus = Oppostatus.new(oppostatus_params)

    respond_to do |format|
      format.html
      format.json { render json: @oppostatus }
    end
  end

  # GET /oppostatuses/1/edit
  def edit
  end

  # POST /oppostatuses
  def create
    @oppostatus = Oppostatus.new(oppostatus_params)

    respond_to do |format|
      if @oppostatus.save
        format.html { redirect_to @oppostatus, notice: "Oppostatus was successfully created." }
        format.json { render json: @oppostatus, status: :created, location: @oppostatus }
      else
        format.html { render action: "new" }
        format.json { render json: @oppostatus.errors, status: :unprocessable_entity }
      end
    end
  end

  # PATCH/PUT /oppostatuses/1
  def update
    respond_to do |format|
      if @oppostatus.update(oppostatus_params)
        format.html { redirect_to @oppostatus, notice: "Oppostatus was successfully updated." }
        format.json { head :no_content }
      else
        format.html { render action: "edit" }
        format.json { render json: @oppostatus.errors, status: :unprocessable_entity }
      end
    end
  end

  # DELETE /oppostatuses/1
  def destroy
    @oppostatus.destroy

    respond_to do |format|
      format.html { redirect_to oppostatuses_url }
      format.json { head :no_content }
    end
  end

  private

  def set_oppostatus
    @oppostatus = Oppostatus.find(params[:id])
  end

  def oppostatus_params
    params.fetch(:oppostatus, {}).permit(:issue, :status, :opportunity_id, :todo_description,
                                         :todo_status, :user_id, :status_mark)
  end
end
