# 订单行管理（草稿加行/删行）；签发与冲销分别走 sales_orders 与 orders#create_return
class OrderLinesController < ApplicationController
  before_action :set_order

  # POST /orders/:order_id/order_lines
  def create
    line = OrderLine.build_with_price_snapshot(@order, line_params)
    if line.save
      redirect_to @order, notice: "#{line.display_no} 已添加"
    else
      redirect_to @order, alert: "加行失败：#{line.errors.full_messages.to_sentence}"
    end
  end

  # PATCH /orders/:order_id/order_lines/:id —— 行快捷编辑（工作台）：数量/版本/交期
  def update
    line = @order.order_lines.find(params[:id])
    line.assign_attributes(line_edit_params)
    if line.allocatable_qty.negative?
      redirect_to update_target,
                  alert: "更新失败：数量不能小于已冲销+已分配量（#{line.quantity - line.allocatable_qty}）"
    elsif line.save
      redirect_to update_target, notice: "#{line.display_no} 已更新"
    else
      redirect_to update_target, alert: "更新失败：#{line.errors.full_messages.to_sentence}"
    end
  rescue ActiveRecord::RecordInvalid => e
    redirect_to update_target, alert: "更新失败：#{e.message}"
  end

  # DELETE /orders/:order_id/order_lines/:id
  def destroy
    line = @order.order_lines.find(params[:id])
    if @order.editable?
      line.destroy
      redirect_to @order, notice: "#{line.display_no} 已删除"
    else
      redirect_to @order, alert: "订单已被生产订单签发，不能删行（请走冲销）"
    end
  end

  private

  def set_order
    @order = Order.find(params[:order_id])
  end

  # 快捷编辑保存后回原页：工作台（return_to=workbench）或订单详情
  def update_target
    params[:return_to] == "workbench" ? workbench_path : @order
  end

  def line_params
    params.require(:order).permit(:generic_part_no, :full_part_no, :quantity, :version, :required_delivery_date,
                                  :base_price, :v1_price, :v2_price, :remark)
  end

  def line_edit_params
    params.require(:order).permit(:quantity, :version, :required_delivery_date)
  end
end
