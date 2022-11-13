class RemoveInvoiceAddressAndDeliverAddressFromCustomer < ActiveRecord::Migration
  def change
    remove_column :customers, :invoice_address, :text
    remove_column :customers, :deliver_address, :text
  end
end
