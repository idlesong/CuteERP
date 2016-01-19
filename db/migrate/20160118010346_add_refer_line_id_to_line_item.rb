class AddReferLineIdToLineItem < ActiveRecord::Migration
  def change
    add_column :line_items, :refer_line_id, :integer
  end
end
