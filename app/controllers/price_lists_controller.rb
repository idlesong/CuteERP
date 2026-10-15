class PriceListsController < ApplicationController
  # GET /price_lists（默认最新批次；?release_id= 查看历史，只读）
  def index
    @release = params[:release_id] ? PriceListRelease.find(params[:release_id]) : PriceListRelease.latest
    @latest = @release&.id == PriceListRelease.latest&.id
    @releases = PriceListRelease.ordered
    @tiers = PriceListEntry::TIERS
    @entries = @release ? @release.entries.ordered : PriceListEntry.none
  end

  # POST /price_lists/create_entry —— 增补：一次写入一个通用型号的全部档位
  # tiers[OEM][1]=价格 … tiers[ODM][100000]=价格，空白档跳过，仅最新批次
  def create_entry
    generic = params[:generic_part_no].to_s.strip
    redirect_to price_lists_path, alert: "请选择通用型号" and return if generic.blank?

    release = PriceListRelease.latest || PriceListRelease.create!(released_at: Date.current)
    tiers = params.permit(tiers: {})[:tiers].to_h

    count = 0
    ActiveRecord::Base.transaction do
      tiers.each do |channel, qtys|
        next unless %w[OEM ODM].include?(channel)

        qtys.each do |qty, price|
          next if price.blank?

          entry = release.entries.find_or_initialize_by(generic_part_no: generic, sell_by: channel, min_qty: qty.to_i)
          entry.price = price
          entry.amended_at = Time.current
          entry.save!
          count += 1
        end
      end
    end
    redirect_to price_lists_path, notice: "已增补 #{generic} 共 #{count} 档（最新批次 #{release.released_at.strftime('%F')}）。"
  rescue ActiveRecord::RecordInvalid => e
    redirect_to price_lists_path, alert: "增补失败：#{e.message}"
  end

  # DELETE /price_lists/destroy_generic?generic_part_no= —— 删除该型号在最新批次的全部档位
  def destroy_generic
    release = PriceListRelease.latest
    generic = params[:generic_part_no].to_s
    release&.entries.where(generic_part_no: generic)&.destroy_all
    redirect_to price_lists_path, notice: "已删除 #{generic} 的全部档位。"
  end

  # POST /price_lists/import —— 定期 Excel 整表导入 = 新批次（不覆盖历史）
  def import
    release = PriceListRelease.create!(released_at: Date.current, note: "Excel 导入")
    count = PriceListEntry.import(params[:file], release)
    redirect_to price_lists_path, notice: "阶梯价导入完成：新批次 #{release.released_at}，共 #{count} 行。"
  rescue StandardError => e
    release&.destroy
    redirect_to price_lists_path, alert: "导入失败：#{e.message}"
  end
end
