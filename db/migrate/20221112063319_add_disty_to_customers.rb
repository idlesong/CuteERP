class AddDistyToCustomers < ActiveRecord::Migration
  def change
    add_reference :customers, :disty, index: true
  end
end
