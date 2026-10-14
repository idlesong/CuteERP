class RenamePriceListEntryReleaseFk < ActiveRecord::Migration[8.1]
  def up
    rename_column :price_list_entries, :release_id, :price_list_release_id
  end

  def down
    rename_column :price_list_entries, :price_list_release_id, :release_id
  end
end
