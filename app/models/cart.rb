class Cart < ActiveRecord::Base
  # has_many :line_items, :as => :line
  has_many :line_items

  def add_po_line_item(price_id, full_part_number, item_quantity, fixed_price, reverse_po_line_id)
    price = Price.find(price_id)
    item = Item.find(price.item_id)
    line_number = 1
    line_number += LineItem.maximum(:id) if LineItem.exists?

  	current_item = line_items.where(:full_part_number => full_part_number).first
  	if current_item
  		current_item.quantity += item_quantity
  	else
  		current_item = line_items.build(
                      :price_id => price_id,
                      :line_number => line_number, 
                      :item_id => price.item_id, 
                      :full_name => item.name,
                      :full_part_number => full_part_number,
                      :quantity => item_quantity, 
                      :fixed_price => fixed_price, 
                      :refer_line_id => reverse_po_line_id)
  	end
  	current_item
  end

  def add_so_line_item(po_line, issue_quantity)
    logger.debug "====##po_line.current_item== "
    if line_items.where(refer_line_id: po_line.id).exists?
      line_item = line_items.where(refer_line_id: po_line.id).first
      line_item.quantity += issue_quantity
      line_item
    else
      if issue_quantity <= po_line.quantity - po_line.quantity_issued
        logger.debug "====$$po_line. build new_item=="
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
  
  def copy_line_items_from_customer_order( order )
    # clear cart line items first.
    self.line_items.clear
    order.line_items.each do |line|
      new_line = line.dup
      new_line.line = nil
      # new_line.line_number = 'cart-' + new_line.line_number # must uniq
      self.line_items << new_line
    end
  end

  def copy_line_items_from_sales_order( sales_order )
    # clear cart line items first.
    self.line_items.clear
    sales_order.line_items.each do |line|
      new_line = line.dup
      new_line.line = nil
      # new_line.line_number = 'cart-' + new_line.line_number # must uniq
      self.line_items << new_line
    end
  end

  def total_price
    line_items.to_a.sum { |item| item.total_price}
  end

  def total_items
    line_items.sum(:quantity)
  end

end
