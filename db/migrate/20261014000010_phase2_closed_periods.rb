# 第二阶段 2.4：关账期间（D12）—— 关账月单据锁定，重开需管理员并留痕
class Phase2ClosedPeriods < ActiveRecord::Migration[8.1]
  def up
    create_table :closed_periods do |t|
      t.date :month, null: false               # 月首日
      t.references :closed_by, null: false     # users
      t.datetime :closed_at, null: false, default: -> { "NOW()" }
      t.references :reopened_by
      t.datetime :reopened_at
      t.timestamps
    end
    add_index :closed_periods, :month, unique: true
  end

  def down
    drop_table :closed_periods
  end
end
