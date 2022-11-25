class AddLineNumberToLineItem < ActiveRecord::Migration
  def change
    add_column :line_items, :line_number, :string
  end
end
