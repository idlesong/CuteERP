class ContactsController < ApplicationController
  before_action :set_contact, only: [:show, :edit, :update, :destroy]

  # GET /contacts
  def index
    @contacts = Contact.all
    @customers = Customer.all

    respond_to do |format|
      format.html
      format.json { render json: @contacts }
    end
  end

  # GET /contacts/1
  def show
    respond_to do |format|
      format.html
      format.json { render json: @contact }
    end
  end

  # GET /contacts/new
  def new
    @contact = Contact.new(contact_params)

    respond_to do |format|
      format.html
      format.json { render json: @contact }
    end
  end

  # GET /contacts/1/edit
  def edit
  end

  # POST /contacts
  def create
    @contact = Contact.new(contact_params)

    respond_to do |format|
      if @contact.save
        format.html { redirect_to @contact, notice: "Contact was successfully created." }
        format.json { render json: @contact, status: :created, location: @contact }
      else
        format.html { render action: "new" }
        format.json { render json: @contact.errors, status: :unprocessable_entity }
      end
    end
  end

  # PATCH/PUT /contacts/1
  def update
    respond_to do |format|
      if @contact.update(contact_params)
        format.html { redirect_to @contact, notice: "Contact was successfully updated." }
        format.json { head :no_content }
      else
        format.html { render action: "edit" }
        format.json { render json: @contact.errors, status: :unprocessable_entity }
      end
    end
  end

  # DELETE /contacts/1
  def destroy
    @contact.destroy

    respond_to do |format|
      format.html { redirect_to contacts_url }
      format.json { head :no_content }
    end
  end

  private

  def set_contact
    @contact = Contact.find(params[:id])
  end

  def contact_params
    params.fetch(:contact, {}).permit(:email, :mobile, :name, :note, :telephone, :title, :customer_id, :address)
  end
end
