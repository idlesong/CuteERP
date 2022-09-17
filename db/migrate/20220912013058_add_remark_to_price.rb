class AddRemarkToPrice < ActiveRecord::Migration
  def change
    add_column :prices, :remark, :string
  end
end
