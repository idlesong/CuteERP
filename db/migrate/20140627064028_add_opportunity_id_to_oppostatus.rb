class AddOpportunityIdToOppostatus < ActiveRecord::Migration
  def change
    add_column :oppostatuses, :opportunity_id, :integer
  end
end
