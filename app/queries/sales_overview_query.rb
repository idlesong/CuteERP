# 销售总览读模型（P5 仪表盘三视图取数源）
# 口径：实际出货 = shipments/shipment_lines；需求净额 = DemandQuery；计划 = sales_plan_entries
class SalesOverviewQuery
  Row = Struct.new(:qty, :chip, :software, :total)

  # ① 实际出货：大类 → 客户（折 RMB），FY 或当月
  # 返回 {group => {customer_name => Row}}
  def self.shipped_by_group(fy: nil, month: nil)
    scope = ShipmentLine.joins(:shipment)
    scope = scope.where(shipments: { shipped_at: SalesPlanEntry.fy_range(fy) }) if fy
    scope = scope.where(shipments: { shipped_at: month.beginning_of_month..month.end_of_month }) if month

    scope.includes(shipment: { sales_order: :customer },
                   production_line: [:item, { production_allocations: { order_line: :order } }])
         .each_with_object({}) do |sl, h|
      pl = sl.production_line
      next unless pl

      group = pl.item&.group.presence || "未分类"
      customer = sl.shipment.sales_order.customer.name
      row = ((h[group] ||= {})[customer] ||= Row.new(0, 0.0, 0.0, 0.0))

      allocs = pl.production_allocations
      total_alloc = allocs.sum(&:quantity).to_f
      next if total_alloc.zero?

      unit_chip  = allocs.sum { |a| a.quantity * (a.order_line&.base_price || 0).to_f } / total_alloc
      unit_soft  = allocs.sum { |a| a.quantity * ((a.order_line&.v1_price || 0) + (a.order_line&.v2_price || 0)).to_f } / total_alloc
      rate = RevenueQuery.exchange_rate_for(pl, sl.shipment.shipped_at)

      row.qty      += sl.quantity
      row.chip     += sl.quantity * unit_chip * rate
      row.software += sl.quantity * unit_soft * rate
      row.total    += sl.quantity * (unit_chip + unit_soft) * rate
    end
  end

  # ① 实际出货月度矩阵（Plan/Budget 同版式，原币口径）：{group => {customer => {月首日 => 值}}}
  def self.shipped_matrix(fy, metric: :quantity)
    scope = ShipmentLine.joins(:shipment)
                        .where(shipments: { shipped_at: SalesPlanEntry.fy_range(fy) })
                        .includes(shipment: { sales_order: :customer },
                                  production_line: [:item, { production_allocations: { order_line: :order } }])

    matrix = Hash.new { |h, k| h[k] = Hash.new { |h2, k2| h2[k2] = Hash.new(0.0) } }
    scope.find_each do |sl|
      pl = sl.production_line
      next unless pl

      allocs = pl.production_allocations
      total_alloc = allocs.sum(&:quantity).to_f
      # 数量不依赖台账；金额需按台账加权定价，无台账记 0
      unit_chip = unit_soft = 0.0
      if total_alloc.positive?
        unit_chip = allocs.sum { |a| a.quantity * (a.order_line&.base_price || 0).to_f } / total_alloc
        unit_soft = allocs.sum { |a| a.quantity * ((a.order_line&.v1_price || 0) + (a.order_line&.v2_price || 0)).to_f } / total_alloc
      end
      value = case metric
              when :chip then sl.quantity * unit_chip
              when :software then sl.quantity * unit_soft
              when :total then sl.quantity * (unit_chip + unit_soft)
              else sl.quantity
              end

      group = pl.item&.group.presence || "未分类"
      customer = sl.shipment.sales_order.customer
      display = customer.name_zh.presence || customer.name
      # 键统一为 Date（视图按 Date 查）
      matrix[group][display][sl.shipment.shipped_at.to_date.beginning_of_month] += value
    end
    matrix
  end

  # ③ 产品视图：product_family 实际出货（折 RMB）
  # 返回 {family => Row}
  def self.shipped_by_family(fy: nil)
    scope = ShipmentLine.joins(:shipment)
    scope = scope.where(shipments: { shipped_at: SalesPlanEntry.fy_range(fy) }) if fy

    scope.includes(shipment: :sales_order,
                   production_line: [:item, { production_allocations: { order_line: :order } }])
         .each_with_object({}) do |sl, h|
      pl = sl.production_line
      next unless pl

      family = pl.item&.family.presence || "未分类"
      row = (h[family] ||= Row.new(0, 0.0, 0.0, 0.0))

      allocs = pl.production_allocations
      total_alloc = allocs.sum(&:quantity).to_f
      next if total_alloc.zero?

      unit = allocs.sum { |a| a.quantity * ((a.order_line&.unit_price || 0)) } / total_alloc
      rate = RevenueQuery.exchange_rate_for(pl, sl.shipment.shipped_at)

      row.qty   += sl.quantity
      row.total += sl.quantity * unit * rate
    end
  end

  # 全年/当月 Plan（数量）对照：{group => {customer => {all_year:, this_month:}}}
  def self.plan_qty_lookup(fy, month = Date.current)
    SalesPlanEntry.fiscal(fy).includes(:customer).each_with_object({}) do |e, h|
      cell = ((h[e.product_group] ||= {})[e.customer.name] ||= { all_year: 0, this_month: 0 })
      cell[:all_year] += e.quantity.to_i
      cell[:this_month] += e.quantity.to_i if e.month.beginning_of_month == month.beginning_of_month
    end
  end
end
