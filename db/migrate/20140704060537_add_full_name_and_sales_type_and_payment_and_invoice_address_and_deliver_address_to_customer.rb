class AddFullNameAndSalesTypeAndPaymentAndInvoiceAddressAndDeliverAddressToCustomer < ActiveRecord::Migration
  def change
    add_column :customers, :full_name, :string
    add_column :customers, :sales_type, :string
    add_column :customers, :payment, :string
    add_column :customers, :invoice_address, :text
    add_column :customers, :deliver_address, :text
  end
end
