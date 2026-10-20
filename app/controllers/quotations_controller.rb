# 客户报价单：选客户 → 勾选其多条价格 → 生成报价单（明细快照，价格可复用）
class QuotationsController < ApplicationController
  before_action :set_quotation, only: [:show, :edit, :update, :destroy]

  # GET /quotations
  def index
    @quotations = Quotation.includes(:customer, :quotation_lines).order(created_at: :desc)
  end

  # GET /quotations/1(.pdf)
  def show
    respond_to do |format|
      format.html
      format.pdf { render pdf: [@quotation.quotation_number, @quotation.customer.name].join("_"),
                          layout: "pdf" }
    end
  end

  # GET /quotations/new?customer_id=
  def new
    @quotation = Quotation.new
    @quotation.quotation_number = Quotation.next_number
    @customer = Customer.find_by(id: params[:customer_id])
    @prices = @customer ? @customer.prices.order(:part_number, :condition) : Price.none
  end

  # POST /quotations
  def create
    price_ids = Array(params[:price_ids]).map(&:to_i).reject(&:zero?)
    if price_ids.empty?
      return redirect_to new_quotation_path(customer_id: params[:customer_id]),
                         alert: "请至少勾选一条价格", body: nil
    end

    @quotation = Quotation.new(customer_id: params[:customer_id],
                               quotation_number: params[:quotation_number].presence || Quotation.next_number,
                               remark: params[:remark])
    if @quotation.save
      @quotation.build_lines_from(price_ids)
      redirect_to @quotation, notice: "报价单已生成：#{@quotation.quotation_number}（#{@quotation.quotation_lines.size} 条价格）"
    else
      redirect_to new_quotation_path(customer_id: params[:customer_id]),
                  alert: @quotation.errors.full_messages.to_sentence
    end
  end

  # GET /quotations/1/edit —— 重选价格（已选项预勾选）
  def edit
    @customer = @quotation.customer
    @prices = @customer.prices.order(:part_number, :condition)
    @selected = @quotation.quotation_lines.map(&:price_id).compact
  end

  # PATCH/PUT /quotations/1
  def update
    if params[:price_ids].present?
      @quotation.build_lines_from(Array(params[:price_ids]).map(&:to_i))
    end
    if @quotation.update(remark: params[:remark])
      redirect_to @quotation, notice: "报价单已更新（#{@quotation.quotation_lines.size} 条价格）"
    else
      render :edit
    end
  end

  # DELETE /quotations/1
  def destroy
    @quotation.destroy
    redirect_to quotations_url, notice: "报价单已删除"
  end

  private

  def set_quotation
    @quotation = Quotation.find(params[:id])
  end
end
