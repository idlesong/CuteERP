class AddGroupAndFamilyToItems < ActiveRecord::Migration
  def change
    add_column :items, :group, :string
    add_column :items, :family, :string
  end
end
