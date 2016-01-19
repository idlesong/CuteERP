class AddOrderNumberToOrder < ActiveRecord::Migration
  def change
    add_column :orders, :order_number, :string
  end
end
