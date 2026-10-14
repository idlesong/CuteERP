# 年度销售计划（P5）：FY 矩阵 + 明细增删 + Plan.xlsx 导入
class SalesPlansController < ApplicationController
  before_action :set_fy

  # GET /sales_plans?fy=2027
  def index
    @fy = (@fy || SalesPlanEntry.current_fy)
    @months = SalesPlanEntry.fy_months(@fy)
    @matrix = SalesPlanEntry.matrix(@fy, metric: :quantity)
    @entries = SalesPlanEntry.fiscal(@fy).includes(:customer).order("customers.name", :product_group, :month)
    @groups = Item.where.not(group: nil).distinct.pluck(:group).sort
  end

  # POST /sales_plans —— 明细 upsert
  def create
    SalesPlanEntry.upsert_entry!(
      fy: params[:fy].presence || @fy,
      customer_id: entry_params[:customer_id],
      product_group: entry_params[:product_group],
      month: entry_params[:month],
      quantity: entry_params[:quantity].to_i,
      chip_amount: entry_params[:chip_amount].to_f,
      software_amount: entry_params[:software_amount].to_f
    )
    redirect_to sales_plans_path(fy: params[:fy].presence || @fy), notice: "计划已保存"
  rescue ActiveRecord::RecordInvalid => e
    redirect_to sales_plans_path(fy: @fy), alert: "保存失败：#{e.message}"
  end

  # POST /sales_plans/import
  def import
    result = SalesPlanEntry.import!(params[:file], fy: params[:fy].presence || @fy)
    notice = "导入完成：#{result[:imported]} 条。"
    notice << " 警告：#{result[:warnings].join('；')}" if result[:warnings].any?
    redirect_to sales_plans_path(fy: @fy), notice: notice
  end

  # DELETE /sales_plans/1
  def destroy
    entry = SalesPlanEntry.find(params[:id])
    entry.destroy
    redirect_to sales_plans_path(fy: @fy), notice: "计划条目已删除"
  end

  private

  def set_fy
    @fy = params[:fy].to_i.positive? ? params[:fy].to_i : SalesPlanEntry.current_fy
  end

  def entry_params
    params.require(:sales_plan_entry).permit(:customer_id, :product_group, :month,
                                             :quantity, :chip_amount, :software_amount)
  end
end
