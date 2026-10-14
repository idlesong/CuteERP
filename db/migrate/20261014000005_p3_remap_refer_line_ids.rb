# P3 补丁：订单侧 line_items 迁为 order_lines 后 id 变化，
# 销售订单行 / 签发暂存行的 refer_line_id 需要重映射到新的 OrderLine
class P3RemapReferLineIds < ActiveRecord::Migration[8.1]
  def up
    say_with_time "remap refer_line_id to order_lines" do
      remapped = 0
      LineItem.where.not(refer_line_id: nil).find_each do |li|
        next if OrderLine.exists?(id: li.refer_line_id) # 已指向新表

        item = li.item_id && Item.find_by(id: li.item_id)
        next unless item

        candidates = OrderLine.where(generic_part_no: item.generic_part_no)
        if candidates.many?
          customer_id =
            if li.line_type == "SalesOrder"
              SalesOrder.find_by(id: li.line_id)&.customer_id
            end
          candidates = candidates.joins(:order).where(orders: { customer_id: customer_id }) if customer_id
        end
        next unless candidates.any?

        li.update_columns(refer_line_id: candidates.first.id)
        remapped += 1
      end
      remapped
    end
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
