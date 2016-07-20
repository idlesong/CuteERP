class AddCreditToCustomer < ActiveRecord::Migration
  def change
    add_column :customers, :credit, :decimal
  end
end
