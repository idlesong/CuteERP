# 出库单列表（创建/删除经由 sales_orders#create_shipment 与 shipments#destroy）
class ShipmentsController < ApplicationController
  # GET /shipments
  def index
    @shipments = Shipment.includes(sales_order: :customer, shipment_lines: :production_line)
                         .order(shipped_at: :desc)
  end

  # DELETE /shipments/1
  def destroy
    shipment = Shipment.find(params[:id])
    sales_order_id = shipment.sales_order_id
    shipment.destroy
    redirect_to request.referer || sales_order_path(sales_order_id), notice: "出库单已删除"
  end
end
