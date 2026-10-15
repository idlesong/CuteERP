# 六联单状态：draft（签发生成）/ submitted（确认提交）；存量单均为已提交
class SixPartOrderStatus < ActiveRecord::Migration[8.1]
  def up
    add_column :sales_orders, :status, :string, default: "draft"
    execute "UPDATE sales_orders SET status = 'submitted'"
  end

  def down
    remove_column :sales_orders, :status
  end
end
