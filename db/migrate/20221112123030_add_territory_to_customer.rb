class AddTerritoryToCustomer < ActiveRecord::Migration
  def change
    add_column :customers, :territory, :string
  end
end
