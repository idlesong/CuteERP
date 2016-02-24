class AddShipContactAndShipAddressAndShipTelephoneToCustomer < ActiveRecord::Migration
  def change
    add_column :customers, :ship_contact, :string
    add_column :customers, :ship_address, :text
    add_column :customers, :ship_telephone, :string
  end
end
