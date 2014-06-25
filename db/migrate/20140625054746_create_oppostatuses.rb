class CreateOppostatuses < ActiveRecord::Migration
  def change
    create_table :oppostatuses do |t|
      t.string :status
      t.string :issue

      t.timestamps
    end
  end
end
