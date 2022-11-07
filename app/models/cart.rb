class Cart < ActiveRecord::Base
  # has_many :line_items, :as => :line
  has_many :line_items

  def add_line_item(item_id, item_suffix, item_quantity, core_price, price_id)
    item = Item.find(item_id)

    item_suffix = '' if (item_suffix == '-' or item_suffix.nil?)
    full_part_number = item.partNo + item_suffix
    full_name = item.name
    price = core_price

  	current_item = line_items.where(:full_part_number => full_part_number).first
  	if current_item
  		current_item.quantity += item_quantity
  	else
  		current_item = line_items.build(:item_id => item_id, :full_part_number => full_part_number,
        :full_name => full_name, :quantity => item_quantity, :fixed_price => price, :price_id => price_id)
  	end
  	current_item
  end

  def issue_line_item(po_line, issue_quantity)
    unless line_items.where(refer_line_id: po_line.id).exists? then
      if issue_quantity <= po_line.quantity - po_line.quantity_issued
        line_item = line_items.build(
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

  # def issue_back_line_item(so_line, issue_back_quantity)
  #   unless line_items.where(line_id: so_line.id).exists? then
  #     if issue_back_quantity <= so_line.quantity
  #       line_item = line_items.build(
  #         item_id: so_line.item_id, 
  #         full_part_number: so_line.full_part_number, 
  #         full_name: so_line.full_name,
  #         quantity: issue_back_quantity, 
  #         # refer_line_id: so_line.id, 
  #         fixed_price: so_line.fixed_price, 
  #         price_id: so_line.price_id,
  #         remark: 'remove'
  #         )
  #     end
  #   end
  # end    

  def issue_refer_line_items
    # issue refer po's line items, after save; and then clear cart
    line_items.each do |line|
      # logger.debug "=====refer_line_id== #{line.refer_line_id}"
      po_line = LineItem.find(line.refer_line_id)
      po_line.update_attribute(:quantity_issued, po_line.quantity_issued + line.quantity)

      line.update_attribute(:cart_id, nil)
    end
  end

  def issue_back_refer_line_items
    line_items.each do |line|
      if (line.remark == "remove" && line.refer_line_id)     
        po_line = LineItem.find(line.refer_line_id)

        # logger.debug "+++++line.quantity-po_line.quantity== #{line.quantity}-#{po_line.quantity_issued}"
        if line.quantity <= po_line.quantity_issued
          po_line.update_attribute(:quantity_issued, po_line.quantity_issued - line.quantity)
        end

        # line.update_attribute(:cart_id, nil)        
      end
    end
  end


  def total_price
    line_items.to_a.sum { |item| item.total_price}
  end

  def total_items
    line_items.sum(:quantity)
  end

end
