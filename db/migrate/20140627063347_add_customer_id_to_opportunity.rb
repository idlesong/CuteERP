class AddCustomerIdToOpportunity < ActiveRecord::Migration
  def change
    add_column :opportunities, :customer_id, :inter
  end
end
