# 净需求查询（D1/D2 口径）：Σ正常单 − Σ冲销 − Σ已分配
# 仪表盘/签发池/列表统一取数入口
class DemandQuery
  # SQL 片段：某 order_line 的已冲销/已分配数量（可嵌入 SELECT 或 WHERE）
  RETURNED_SQL = "COALESCE((SELECT -SUM(r.quantity) FROM order_lines r WHERE r.refer_order_line_id = order_lines.id), 0)".freeze
  ALLOCATED_SQL = "COALESCE((SELECT SUM(pa.quantity) FROM production_allocations pa WHERE pa.order_line_id = order_lines.id), 0)".freeze

  # 未分配完的客户订单行（净需求 > 已分配），供签发池（仅已提交）
  def self.allocatable_lines(customer_id: nil)
    scope = OrderLine.joins(:order)
                     .where(orders: { kind: "normal", status: "submitted" })
                     .where("(order_lines.quantity - #{RETURNED_SQL} - #{ALLOCATED_SQL}) > 0")
                     .order("orders.po_number", "order_lines.line_no")
    scope = scope.where(orders: { customer_id: customer_id }) if customer_id
    scope
  end

  # 工作台待办行：草稿 + 已提交未分配完（草稿行带提交链接、已提交行带分解链接）
  def self.actionable_lines
    OrderLine.joins(:order)
             .includes(order: [:customer, :end_customer])
             .where(orders: { kind: "normal", status: %w[draft submitted] })
             .where("(order_lines.quantity - #{RETURNED_SQL} - #{ALLOCATED_SQL}) > 0")
             .order("orders.po_number", "order_lines.line_no")
  end

  # 全部正常行 + 净需求/已分配/剩余（列表、仪表盘）
  def self.normal_lines_with_demand
    OrderLine.joins(:order)
             .where(orders: { kind: "normal" })
             .select("order_lines.*",
                     "(order_lines.quantity - #{RETURNED_SQL}) AS net_qty",
                     "#{ALLOCATED_SQL} AS allocated_qty",
                     "(order_lines.quantity - #{RETURNED_SQL} - #{ALLOCATED_SQL}) AS remaining_qty")
             .order("orders.po_number", "order_lines.line_no")
  end
end
