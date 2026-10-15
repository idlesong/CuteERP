# 首页/销售总览（P5 三视图）+ 快捷区：
# - 未签发客户订单 = 复用客户订单行表格（仅含可分配行，不分页）
# - 未发货六联单（含出货列）
class AdminController < ApplicationController
  METRICS = { qty: :quantity, chip: :chip_amount, software: :software_amount, total: :total_amount }.freeze

  def index
    @fy = params[:fy].to_i.positive? ? params[:fy].to_i : SalesPlanEntry.current_fy
    @this_month = Date.current.beginning_of_month

    # ① 实际出货（FY）
    @shipped = SalesOverviewQuery.shipped_by_group(fy: @fy)
    @plan_lookup = SalesOverviewQuery.plan_qty_lookup(@fy, @this_month)

    # ② Plan 视图
    @metric = METRICS.fetch(params[:metric].to_s.to_sym, :quantity)
    @plan_matrix = SalesPlanEntry.matrix(@fy, metric: @metric)
    @fy_months = SalesPlanEntry.fy_months(@fy)

    # ③ 产品视图
    @family = SalesOverviewQuery.shipped_by_family(fy: @fy)

    # 快捷区：未签发行（复用客户订单行表格，不分页）+ 未发货六联单
    @unissued_lines = DemandQuery.allocatable_lines
                                 .includes(order: [:customer, :end_customer])
    @unshipped_orders = SalesOrder.includes(:customer, :production_lines)
                                  .where.missing(:shipments)
                                  .order(created_at: :desc)
  end
end
