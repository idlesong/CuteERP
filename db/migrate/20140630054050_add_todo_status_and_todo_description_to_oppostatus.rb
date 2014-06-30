class AddTodoStatusAndTodoDescriptionToOppostatus < ActiveRecord::Migration
  def change
    add_column :oppostatuses, :todo_status, :string
    add_column :oppostatuses, :todo_description, :string
  end
end
