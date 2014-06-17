class CreateContacts < ActiveRecord::Migration
  def change
    create_table :contacts do |t|
      t.string :name
      t.string :title
      t.string :mobile
      t.string :telephone
      t.string :email
      t.string :note

      t.timestamps
    end
  end
end
