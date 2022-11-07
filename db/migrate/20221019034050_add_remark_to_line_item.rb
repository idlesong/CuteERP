class AddRemarkToLineItem < ActiveRecord::Migration
  def change
    add_column :line_items, :remark, :string
  end
end
