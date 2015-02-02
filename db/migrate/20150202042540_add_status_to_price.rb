class AddStatusToPrice < ActiveRecord::Migration
  def change
    add_column :prices, :status, :string
  end
end
