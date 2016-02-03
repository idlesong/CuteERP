class Cart < ActiveRecord::Base
  # attr_accessible :title, :body
  # has_many :line_items, :as => :line
  has_many :line_items

  def add_item(item_id, item_quantity, price)
  	current_item = line_items.where(:item_id => item_id).first
  	if current_item
  		current_item.quantity += item_quantity
  	else
  		current_item = line_items.build(:item_id => item_id,
        :quantity => item_quantity, :price => price)
  	end
  	current_item
  end

  def issue_line_item(po_line, item_quantity)
    # unless line_items.where(refer_line_id: po_line.id).exists? then
      # if quantity_left = po_line.quantity - po_line.quantity_issued > 0 then
        line_item = line_items.build(item_id: po_line.item_id,
          quantity: item_quantity, refer_line_id: po_line.id, price: po_line.price)
      # end
    # end
  end

  def total_price
    line_items.to_a.sum { |item| item.total_price}
  end

  def total_items
    line_items.sum(:quantity)
  end

end
