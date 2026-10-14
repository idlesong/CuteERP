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

  # DELETE /orders/:order_id/order_lines/:id
  def destroy
    line = @order.order_lines.find(params[:id])
    if @order.draft?
      line.destroy
      redirect_to @order, notice: "#{line.display_no} 已删除"
    else
      redirect_to @order, alert: "只有草稿单可以删行"
    end
  end

  private

  def set_order
    @order = Order.find(params[:order_id])
  end

  def line_params
    params.require(:order).permit(:generic_part_no, :quantity, :version, :required_delivery_date,
                                  :base_price, :v1_price, :v2_price, :remark)
  end
end
