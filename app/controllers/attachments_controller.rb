class AttachmentsController < ApplicationController
  before_action :set_attachment, only: [:show, :edit, :update, :destroy]

  # GET /attachments
  def index
    @attachments = Attachment.all

    respond_to do |format|
      format.html
      format.json { render json: @attachments }
    end
  end

  # GET /attachments/1
  def show
    respond_to do |format|
      format.html
      format.json { render json: @attachment }
    end
  end

  # GET /attachments/new
  def new
    @attachment = Attachment.new

    respond_to do |format|
      format.html
      format.json { render json: @attachment }
    end
  end

  # GET /attachments/1/edit
  def edit
  end

  # POST /attachments
  def create
    @attachment = Attachment.new(attachment_params)
    @attachment.document.attach(params[:attachment][:document]) if params[:attachment][:document].present?

    respond_to do |format|
      if @attachment.save
        format.html { redirect_to @attachment, notice: "Attachment was successfully created." }
        format.json { render json: @attachment, status: :created, location: @attachment }
      else
        format.html { render action: "new" }
        format.json { render json: @attachment.errors, status: :unprocessable_entity }
      end
    end
  end

  # PATCH/PUT /attachments/1
  def update
    if params[:attachment][:document].present?
      @attachment.document.attach(params[:attachment][:document])
    end

    respond_to do |format|
      if @attachment.update(attachment_params)
        format.html { redirect_to @attachment, notice: "Attachment was successfully updated." }
        format.json { head :no_content }
      else
        format.html { render action: "edit" }
        format.json { render json: @attachment.errors, status: :unprocessable_entity }
      end
    end
  end

  # DELETE /attachments/1
  def destroy
    @attachment.destroy

    respond_to do |format|
      format.html { redirect_to attachments_url }
      format.json { head :no_content }
    end
  end

  private

  def set_attachment
    @attachment = Attachment.find(params[:id])
  end

  def attachment_params
    params.require(:attachment).permit(:name, :description, :post_id)
  end
end
