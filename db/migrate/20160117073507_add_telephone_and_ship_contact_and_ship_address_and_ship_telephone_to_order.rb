class AddTelephoneAndShipContactAndShipAddressAndShipTelephoneToOrder < ActiveRecord::Migration
  def change
    add_column :orders, :telephone, :string
    add_column :orders, :ship_contact, :string
    add_column :orders, :ship_address, :text
    add_column :orders, :ship_telephone, :string
  end
end
