class AddCartIdToLineItem < ActiveRecord::Migration
  def change
    add_column :line_items, :cart_id, :integer
  end
end
