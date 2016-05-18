class AddIndexToItem < ActiveRecord::Migration
  def change
    add_column :items, :index, :integer
  end
end
