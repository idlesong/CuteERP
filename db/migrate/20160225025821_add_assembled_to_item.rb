class AddAssembledToItem < ActiveRecord::Migration
  def change
    add_column :items, :assembled, :string
  end
end
