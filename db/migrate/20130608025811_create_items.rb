class CreateItems < ActiveRecord::Migration
  def change
    create_table :items do |t|
      t.string :name
      t.string :partNo
      t.string :package
      t.string :imageURL
      t.decimal :price, :precision => 8, :scale => 2

      t.timestamps
    end
  end
end
