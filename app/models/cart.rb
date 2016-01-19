class Cart < ActiveRecord::Base
  # attr_accessible :title, :body
  has_many :line_items, :as => :line

  # has_many :issued_line_items, class_name: "LineItem"

  def add_item(item_id)
  	current_item = line_items.where(:item_id => item_id).first
  	if current_item
  		current_item.quantity += 1
  	else
  		current_item = line_items.build(:item_id => item_id)
  	end
  	current_item
  end

  def issue_line_item(po_line)
    unless line_items.where(refer_line_id: po_line.id).exists? then
      if quantity_left = po_line.quantity - po_line.quantity_issued > 0 then
        line_item = line_items.build(item_id: po_line.item_id,
          quantity: quantity_left, refer_line_id: po_line.id)
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
