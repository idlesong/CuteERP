class AddAddressToContact < ActiveRecord::Migration
  def change
    add_column :contacts, :address, :string
  end
end
