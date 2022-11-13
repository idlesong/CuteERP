class AddEndCutomerIdToOrder < ActiveRecord::Migration
  def change
    add_column :orders, :end_customer_id, :integer
  end
end
