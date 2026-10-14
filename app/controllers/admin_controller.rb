# 仪表盘（P5）：三视图取数走 SalesOverviewQuery / DemandQuery
# ① 实际出货（大类→客户，对比全年/当月 Plan） ② Plan 视图（货币段→大类→客户，度量切换） ③ 产品视图（family）
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
  end
end
