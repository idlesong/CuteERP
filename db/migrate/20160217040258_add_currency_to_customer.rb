class AddCurrencyToCustomer < ActiveRecord::Migration
  def change
    add_column :customers, :currency, :string, :default => 'RMB'
  end
end
