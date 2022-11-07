class AddBaseItemAndExtraItemToItem < ActiveRecord::Migration
  def change
    add_column :items, :base_item, :string
    add_column :items, :extra_item, :string
  end
end
