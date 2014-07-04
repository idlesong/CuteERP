class AddEmailAndTelephoneToUser < ActiveRecord::Migration
  def change
    add_column :users, :email, :string
    add_column :users, :telephone, :string
  end
end
