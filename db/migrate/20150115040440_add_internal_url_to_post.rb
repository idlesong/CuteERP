class AddInternalUrlToPost < ActiveRecord::Migration
  def change
    add_column :posts, :internal_url, :string
  end
end
