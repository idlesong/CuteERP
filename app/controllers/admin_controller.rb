# 仪表盘（P4 过渡版：未签发行池 + 今年生产订单；P5 重排为三视图）
class AdminController < ApplicationController
  def index
    # 未签发完的客户订单行（净需求 > 已分配）
    @open_lines = DemandQuery.allocatable_lines

    this_year = (Time.current.beginning_of_year..)
    @sales_orders = SalesOrder.includes(:customer, :production_lines)
                              .where(created_at: this_year)
  end
end
