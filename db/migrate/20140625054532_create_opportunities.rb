class CreateOpportunities < ActiveRecord::Migration
  def change
    create_table :opportunities do |t|
      t.string :priority
      t.string :project_type
      t.string :solution
      t.string :note

      t.timestamps
    end
  end
end
