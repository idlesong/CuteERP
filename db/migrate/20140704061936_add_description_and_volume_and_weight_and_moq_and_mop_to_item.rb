class AddDescriptionAndVolumeAndWeightAndMoqAndMopToItem < ActiveRecord::Migration
  def change
    add_column :items, :description, :string
    add_column :items, :volume, :decimal
    add_column :items, :weight, :decimal
    add_column :items, :moq, :integer
    add_column :items, :mop, :integer
  end
end
