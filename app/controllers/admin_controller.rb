# 首页/销售总览（P5 三视图）+ 快捷区：
# - 未签发客户订单 = 复用客户订单行表格（仅含可分配行，不分页）
# - 未发货六联单（含出货列）
class AdminController < ApplicationController
  # 工作台（用户页）：销售操作起点——未签发客户订单 + 未发货六联单
  def workbench
    @unissued_lines = DemandQuery.allocatable_lines
                                 .includes(order: [:customer, :end_customer])
    # 未全部发货：还有未出完生产行的六联单（含发了部分没发完的）
    orders = SalesOrder.includes(:customer, :production_lines).order(created_at: :desc)
    @unshipped_orders = orders.reject do |so|
      so.production_lines.all? { |pl| pl.unshipped_qty <= 0 }
    end
  end

  # 工作台（用户页）：销售操作起点——未签发客户订单 + 未发货六联单
  def workbench
    @unissued_lines = DemandQuery.allocatable_lines
                                 .includes(order: [:customer, :end_customer])
    # 未全部发货：还有未出完生产行的六联单（含发了部分没发完的）
    orders = SalesOrder.includes(:customer, :production_lines).order(created_at: :desc)
    @unshipped_orders = orders.reject do |so|
      so.production_lines.all? { |pl| pl.unshipped_qty <= 0 }
    end
  end

  METRICS = { qty: :quantity, chip: :chip_amount, software: :software_amount, total: :total_amount }.freeze
  # 实际出货矩阵的度量键（区别于 Plan 条目字段名）
  SHIPPED_METRICS = { qty: :quantity, chip: :chip, software: :software, total: :total }.freeze

  def index
    @fy = params[:fy].to_i.positive? ? params[:fy].to_i : SalesPlanEntry.current_fy
    @this_month = Date.current.beginning_of_month

    # ① 实际出货（FY，Plan 式月度矩阵，四度量切换）
    @shipped_metric = SHIPPED_METRICS.fetch(params[:shipped_metric].to_s.to_sym, :quantity)
    @shipped_matrix = SalesOverviewQuery.shipped_matrix(@fy, metric: @shipped_metric)

    # ② Plan 视图
    @metric = METRICS.fetch(params[:metric].to_s.to_sym, :quantity)
    @plan_matrix = SalesPlanEntry.matrix(@fy, metric: @metric)
    @fy_months = SalesPlanEntry.fy_months(@fy)

    # ③ 产品视图
    @family = SalesOverviewQuery.shipped_by_family(fy: @fy)

    # 快捷区：未签发行（复用客户订单行表格，不分页）+ 未发货六联单
    @unissued_lines = DemandQuery.allocatable_lines
                                 .includes(order: [:customer, :end_customer])
    # 未全部发货：还有未出完生产行的六联单（含发了部分没发完的）
    orders = SalesOrder.includes(:customer, :production_lines).order(created_at: :desc)
    @unshipped_orders = orders.reject do |so|
      so.production_lines.all? { |pl| pl.unshipped_qty <= 0 }
    end
  end
end
