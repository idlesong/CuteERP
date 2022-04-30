class AddQuotationIdToPrice < ActiveRecord::Migration
  def change
    add_column :prices, :quotation_id, :integer
  end
end
