class AddFullPartNumberAndFullNameToLineItem < ActiveRecord::Migration
  def change
    add_column :line_items, :full_part_number, :string
    add_column :line_items, :full_name, :string
  end
end
