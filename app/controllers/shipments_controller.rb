# 出库单列表（创建/删除经由 sales_orders#create_shipment 与 shipments#destroy）
class ShipmentsController < ApplicationController
  # GET /shipments?month=2026-10 —— 月份筛选（空 = 全部）
  def index
    scope = Shipment.includes(sales_order: :customer, shipment_lines: { production_line: :item })
    scope = scope.where(shipped_at: Date.parse("#{params[:month]}-01").all_month) if params[:month].to_s.match?(/\A\d{4}-\d{2}\z/)
    @shipments = scope.order(shipped_at: :desc)
    @month = params[:month].presence
  end

  # POST /shipments?inline=1 —— 整单出库（该六联单全部未出库数量一次出完）
  def create
    so = SalesOrder.find(params[:sales_order_id])
    if so.draft?
      redirect_to shipments_path, alert: "草稿六联单请先提交后再出库"
      return
    end
    shipment = Shipment.build_for(so,
                                  shipped_at: params[:shipped_at].presence || Time.current,
                                  tracking_no: params[:tracking_no].presence,
                                  note: params[:note].presence,
                                  total_qty: params[:quantity].present? ? params[:quantity].to_i : nil)
    if shipment.save
      redirect_to shipments_path, notice: "出库单已创建（#{so.serial_number}，共 #{shipment.shipment_lines.sum(:quantity)} 件）"
    else
      redirect_to shipments_path, alert: "出库失败：#{shipment.errors.full_messages.to_sentence}"
    end
  end

  # DELETE /shipments/1
  def destroy
    shipment = Shipment.find(params[:id])
    sales_order_id = shipment.sales_order_id
    shipment.destroy
    redirect_to request.referer || sales_order_path(sales_order_id), notice: "出库单已删除"
  end
end
