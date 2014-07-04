class AddUserIdToOppostatus < ActiveRecord::Migration
  def change
    add_column :oppostatuses, :user_id, :integer
  end
end
