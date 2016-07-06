class AddRemarkToOrder < ActiveRecord::Migration
  def change
    add_column :orders, :remark, :string
  end
end
