class CreateSalesOrders < ActiveRecord::Migration
  def change
    create_table :sales_orders do |t|
      t.string :serial_number
      t.integer :customer_id
      t.string :bill_contact
      t.text :bill_address
      t.string :bill_telephone
      t.string :ship_contact
      t.text :ship_address
      t.string :ship_telephone
      t.string :payment_term

      t.timestamps
    end
  end
end
