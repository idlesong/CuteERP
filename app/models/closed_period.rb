# 关账期间（第二阶段 2.4，D12）：关账月单据锁定，重开需管理员并留痕
class ClosedPeriod < ApplicationRecord
  belongs_to :closed_by, class_name: "User"
  belongs_to :reopened_by, class_name: "User", optional: true

  validates :month, presence: true, uniqueness: true

  scope :active, -> { where(reopened_at: nil) }

  # 某日期所在月是否已关账
  def self.closed?(date)
    active.exists?(month: date.beginning_of_month)
  end

  # 供单据模型锁定的统一入口：返回是否允许变更/删除
  def self.allow_change?(date)
    !closed?(date)
  end

  def open?
    reopened_at.nil?
  end
end
