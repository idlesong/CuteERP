# 关账锁定的共享校验（客户订单 / 六联单 / 出库单）
# 用法（模型内）：include ClosedPeriodGuard；锁定按各模型声明的锁定日期：
#   def closed_period_date = created_at  (客户订单/六联单)
#   def closed_period_date = shipped_at  (出库单)
module ClosedPeriodGuard
  extend ActiveSupport::Concern

  included do
    before_destroy :ensure_period_open
    before_update :ensure_period_open
  end

  def closed_period_field
    self.class.closed_period_field
  end

  def ensure_period_open
    date = public_send(closed_period_field)
    return true if date.nil? || ClosedPeriod.allow_change?(date)

    errors.add(:base, "单据所在月份（#{date.beginning_of_month.strftime('%Y-%m')}）已关账锁定，如需修改请先重开该月")
    throw :abort
  end

  class_methods do
    attr_writer :closed_period_field

    def closed_period_field
      @closed_period_field || "created_at"
    end

    def locks_closed_periods_on(field)
      @closed_period_field = field.to_s
    end
  end
end
