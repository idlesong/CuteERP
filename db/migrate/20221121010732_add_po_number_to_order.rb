class AddPoNumberToOrder < ActiveRecord::Migration
  def change
    add_column :orders, :po_number, :string
  end
end
