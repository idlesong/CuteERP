class AddLineIdAndLineTypeToLineItem < ActiveRecord::Migration
  def change
    add_column :line_items, :line_id, :integer
    add_column :line_items, :line_type, :string

    add_index :line_items, :line_id  
  end


end
