class AddIsPrrToPrice < ActiveRecord::Migration
  def change
    add_column :prices, :is_prr, :integer
  end
end
