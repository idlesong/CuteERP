class AddStatusMarkToOppostatus < ActiveRecord::Migration
  def change
    add_column :oppostatuses, :status_mark, :string
  end
end
