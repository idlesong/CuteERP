class ItemsController < ApplicationController
  before_action :set_item, only: [:show, :edit, :update, :destroy]

  # GET /items
  def index
    @items = Item.order(:id).where.not(index: 0)

    respond_to do |format|
      format.html
      format.json { render json: ItemsDatatable.new(view_context) }

      format.csv { send_data @items.export_to_csv }
      format.xls { send_data @items.export_to_csv(col_sep: "\t") }
    end
  end

  # GET /items/1
  def show
    @post = Post.where("internal_url = ?", @item.partNo)

    respond_to do |format|
      format.html
      format.json { render json: @item }
    end
  end

  # GET /items/new
  def new
    @item = Item.new

    respond_to do |format|
      format.html
      format.json { render json: @item }
    end
  end

  # GET /items/1/edit
  def edit
  end

  # POST /items
  def create
    @item = Item.new(item_params)

    respond_to do |format|
      if @item.save
        format.html { redirect_to @item, notice: "Item was successfully created." }
        format.json { render json: @item, status: :created, location: @item }
      else
        format.html { render action: "new" }
        format.json { render json: @item.errors, status: :unprocessable_entity }
      end
    end
  end

  # PATCH/PUT /items/1
  def update
    respond_to do |format|
      if @item.update(item_params)
        format.html { redirect_to @item, notice: "Item was successfully updated." }
        format.json { head :no_content }
      else
        format.html { render action: "edit" }
        format.json { render json: @item.errors, status: :unprocessable_entity }
      end
    end
  end

  # DELETE /items/1
  def destroy
    respond_to do |format|
      if @item.destroy
        format.html { redirect_to items_url }
        format.json { head :no_content }
      else
        format.html { redirect_to item_url(@item), notice: "Item can't be destroyed" }
        format.json { render json: @item.errors, status: :unprocessable_entity }
      end
    end
  end

  # GET /items/1/who_bought
  def who_bought
    @item = Item.find(params[:id])
    # Item has no has_many :orders through line_items (polymorphic line), so query directly
    @orders = Order.where(id: @item.line_items.where(line_type: "Order").select(:line_id)).distinct

    respond_to do |format|
      format.atom
      format.xml { render xml: @item.attributes.to_xml }
    end
  end

  # POST /items/import
  def import
    Item.import(params[:file])
    redirect_to items_url, notice: "Products imported."
  end

  private

  def set_item
    @item = Item.find(params[:id])
  end

  def item_params
    params.require(:item).permit(:imageURL, :name, :generic_part_no, :suffix, :description,
                                 :volume, :weight, :moq, :mop, :assembled, :index,
                                 :base_item, :extra_item, :extra_item2, :group, :family,
                                 :name_zh, :eol_at)
  end
end
