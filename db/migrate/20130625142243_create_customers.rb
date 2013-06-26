class CreateCustomers < ActiveRecord::Migration
  def change
    create_table :customers do |t|
      t.string :name
      t.text :address
      t.date :since
      t.decimal :balance
      t.string :contact
      t.string :telephone

      t.timestamps
    end
  end
end
