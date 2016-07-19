class Cart < ActiveRecord::Base
  # has_many :line_items, :as => :line
  has_many :line_items

  def add_item(item_id, item_addition_id, item_suffix, item_quantity, core_price, addition_price)
    item = Item.find(item_id)
    if item_addition_id.nil?
      full_part_number = item.partNo
      full_name = item.name
      price = core_price
    else
      addition = Item.find(item_addition_id)
      item_suffix = '' if item_suffix == '-' or item_suffix.nil?
      full_part_number = item.partNo + addition.partNo + item_suffix
      full_part_number[0, 1]='' if addition.partNo == 'D'
      full_name = item.name + ':' + item.description + ',' + addition.name
      price = core_price + addition_price
    end

  	current_item = line_items.where(:full_part_number => full_part_number).first
  	if current_item
  		current_item.quantity += item_quantity
  	else
  		current_item = line_items.build(:item_id => item_id, :full_part_number => full_part_number,
        :full_name => full_name, :quantity => item_quantity, :price => price)
  	end
  	current_item
  end

  def issue_line_item(po_line, issue_quantity)
    unless line_items.where(refer_line_id: po_line.id).exists? then
      if issue_quantity <= po_line.quantity - po_line.quantity_issued
        line_item = line_items.build(item_id: po_line.item_id,
          full_part_number: po_line.full_part_number, full_name: po_line.full_name,
          quantity: issue_quantity, refer_line_id: po_line.id, price: po_line.price)
      end
    end
  end

  def issue_refer_line_items
    # issue refer po's line items, after save; and then clear cart
    line_items.each do |line|
      # logger.debug "=====refer_line_id== #{line.refer_line_id}"
      po_line = LineItem.find(line.refer_line_id)
      po_line.update_attribute(:quantity_issued, po_line.quantity_issued + line.quantity)

      line.update_attribute(:cart_id, nil)
    end
  end

  def total_price
    line_items.to_a.sum { |item| item.total_price}
  end

  def total_items
    line_items.sum(:quantity)
  end

end
