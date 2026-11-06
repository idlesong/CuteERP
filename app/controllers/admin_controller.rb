# 首页/销售总览（P5 三视图）+ 快捷区：
# - 未签发客户订单 = 复用客户订单行表格（仅含可分配行，不分页）
# - 未发货六联单（含出货列）
# 销售总览金额显示口径：不含税（÷1.13）、整数——由 untax_matrix 在 controller 层换算，
# 数量度量不换算；其他页面金额照常含税/两位小数
class AdminController < ApplicationController
  METRICS = { qty: :quantity, chip: :chip_amount, software: :software_amount, total: :total_amount }.freeze
  # 实际出货矩阵的度量键（区别于 Plan 条目字段名）
  SHIPPED_METRICS = { qty: :quantity, chip: :chip, software: :software, total: :total }.freeze

  # 矩阵值统一换算为不含税（÷1.13，MonthlyWorkbook::TAX_FACTOR 同口径）
  def self.untax_matrix(matrix)
    matrix.transform_values do |customers|
      customers.transform_values do |cells|
        cells.transform_values { |v| (v / MonthlyWorkbook::TAX_FACTOR).round(2) }
      end
    end
  end

  # 工作台（用户页）：销售操作起点——未签发客户订单 + 未发货六联单
  def workbench
    @unissued_lines = DemandQuery.actionable_lines
    # 未全部发货：还有未出完生产行的六联单（含发了部分没发完的）
    orders = SalesOrder.includes(:customer, :production_lines).order(created_at: :desc)
    @unshipped_orders = orders.reject do |so|
      so.production_lines.all? { |pl| pl.unshipped_qty <= 0 }
    end
  end

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

    # ③ 客户订单视图（与实际出货同版式：数量/芯片额/软件额/总额）
    @order_metric = SHIPPED_METRICS.fetch(params[:order_metric].to_s.to_sym, :quantity)
    @order_matrix = SalesOverviewQuery.order_matrix(@fy, metric: @order_metric)

    # 金额度量统一换算不含税（数量保持原值）
    @shipped_matrix = AdminController.untax_matrix(@shipped_matrix) if @shipped_metric != :quantity
    @plan_matrix = AdminController.untax_matrix(@plan_matrix) if @metric != :quantity
    @order_matrix = AdminController.untax_matrix(@order_matrix) if @order_metric != :quantity

    # 快捷区：未签发行（复用客户订单行表格，不分页）+ 未发货六联单
    @unissued_lines = DemandQuery.actionable_lines
    # 未全部发货：还有未出完生产行的六联单（含发了部分没发完的）
    orders = SalesOrder.includes(:customer, :production_lines).order(created_at: :desc)
    @unshipped_orders = orders.reject do |so|
      so.production_lines.all? { |pl| pl.unshipped_qty <= 0 }
    end
  end
end
