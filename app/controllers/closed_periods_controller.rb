# 关账与归档（第二阶段 2.4，D12/D13）
class ClosedPeriodsController < ApplicationController
  # GET /closed_periods
  def index
    @closed_periods = ClosedPeriod.order(:month)
    @month = params[:month].presence || Date.current.prev_month.strftime("%Y-%m")
    @closed = ClosedPeriod.find_by(month: parse_month(@month))
  end

  # POST /closed_periods —— 关账：锁定 + 自动归档（pg_dump + 当月工作簿）
  def create
    month = parse_month(params[:month])
    if month.nil?
      redirect_to closed_periods_path, alert: "月份无效" and return
    end
    if ClosedPeriod.active.exists?(month: month)
      redirect_to closed_periods_path, alert: "#{month.strftime('%Y-%m')} 已处于关账状态" and return
    end

    archive_result = BackupService.archive_month(month)
    period = ClosedPeriod.find_or_initialize_by(month: month)
    period.assign_attributes(closed_by: current_user, closed_at: Time.current,
                             reopened_by: nil, reopened_at: nil)
    period.save!
    redirect_to closed_periods_path, notice: "#{month.strftime('%Y-%m')} 已关账并归档（#{archive_result}）"
  end

  # DELETE /closed_periods/:id —— 重开（管理员，留痕）
  def destroy
    period = ClosedPeriod.find(params[:id])
    if period.open?
      period.update(reopened_by: current_user, reopened_at: Time.current)
      redirect_to closed_periods_path, notice: "#{period.month.strftime('%Y-%m')} 已重开（操作人：#{current_user.name}），修改后请重新关账"
    else
      redirect_to closed_periods_path, alert: "该月已是重开状态"
    end
  end

  private

  def parse_month(raw)
    Date.strptime(raw.to_s, "%Y-%m").beginning_of_month
  rescue ArgumentError, TypeError
    nil
  end
end
