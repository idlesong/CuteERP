# 签发暂存购物车（P4 由分配台账 D2 替代）
class Cart < ActiveRecord::Base
  has_many :line_items

  def add_so_line_item(po_line, issue_quantity)
    if line_items.where(refer_line_id: po_line.id).exists?
      line_item = line_items.where(refer_line_id: po_line.id).first
      line_item.quantity += issue_quantity
      line_item
    else
      if issue_quantity <= po_line.quantity - po_line.quantity_issued
        line_item = line_items.build(
          line_number: LineItem.maximum(:id) + 1,
          item_id: po_line.item_id,
          full_part_number: po_line.full_part_number,
          full_name: po_line.full_name,
          quantity: issue_quantity,
          refer_line_id: po_line.id,
          fixed_price: po_line.fixed_price,
          price_id: po_line.price_id)
      end
    end
  end

  def copy_line_items_from_sales_order(sales_order)
    # clear cart line items first.
    self.line_items.clear
    sales_order.line_items.each do |line|
      new_line = line.dup
      new_line.line = nil
      self.line_items << new_line
    end
  end

  def total_price
    line_items.to_a.sum { |item| item.total_price }
  end

  def total_items
    line_items.sum(:quantity)
  end
end
