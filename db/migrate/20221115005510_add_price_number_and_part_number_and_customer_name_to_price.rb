class AddPriceNumberAndPartNumberAndCustomerNameToPrice < ActiveRecord::Migration
  def change
    add_column :prices, :price_number, :string
    add_column :prices, :part_number, :string
    add_column :prices, :customer_name, :string
  end
end
