class OppostatusesController < ApplicationController
  # GET /oppostatuses
  # GET /oppostatuses.json
  def index
    @oppostatuses = Oppostatus.all

    respond_to do |format|
      format.html # index.html.erb
      format.json { render json: @oppostatuses }
    end
  end

  # GET /oppostatuses/1
  # GET /oppostatuses/1.json
  def show
    @oppostatus = Oppostatus.find(params[:id])

    respond_to do |format|
      format.html # show.html.erb
      format.json { render json: @oppostatus }
    end
  end

  # GET /oppostatuses/new
  # GET /oppostatuses/new.json
  def new
    @oppostatus = Oppostatus.new

    respond_to do |format|
      format.html # new.html.erb
      format.json { render json: @oppostatus }
    end
  end

  # GET /oppostatuses/1/edit
  def edit
    @oppostatus = Oppostatus.find(params[:id])
  end

  # POST /oppostatuses
  # POST /oppostatuses.json
  def create
    @oppostatus = Oppostatus.new(params[:oppostatus])

    respond_to do |format|
      if @oppostatus.save
        format.html { redirect_to @oppostatus, notice: 'Oppostatus was successfully created.' }
        format.json { render json: @oppostatus, status: :created, location: @oppostatus }
      else
        format.html { render action: "new" }
        format.json { render json: @oppostatus.errors, status: :unprocessable_entity }
      end
    end
  end

  # PUT /oppostatuses/1
  # PUT /oppostatuses/1.json
  def update
    @oppostatus = Oppostatus.find(params[:id])

    respond_to do |format|
      if @oppostatus.update_attributes(params[:oppostatus])
        format.html { redirect_to @oppostatus, notice: 'Oppostatus was successfully updated.' }
        format.json { head :no_content }
      else
        format.html { render action: "edit" }
        format.json { render json: @oppostatus.errors, status: :unprocessable_entity }
      end
    end
  end

  # DELETE /oppostatuses/1
  # DELETE /oppostatuses/1.json
  def destroy
    @oppostatus = Oppostatus.find(params[:id])
    @oppostatus.destroy

    respond_to do |format|
      format.html { redirect_to oppostatuses_url }
      format.json { head :no_content }
    end
  end
end
