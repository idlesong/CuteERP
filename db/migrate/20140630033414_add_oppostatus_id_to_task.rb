class AddOppostatusIdToTask < ActiveRecord::Migration
  def change
    add_column :tasks, :oppostatus_id, :integer
  end
end
