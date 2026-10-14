class PriceListsController < ApplicationController
  # GET /price_lists（默认最新批次；?release_id= 查看历史，只读）
  def index
    @release = params[:release_id] ? PriceListRelease.find(params[:release_id]) : PriceListRelease.latest
    @latest = @release&.id == PriceListRelease.latest&.id
    @releases = PriceListRelease.ordered
    @tiers = [1, 1000, 2500, 5000, 10000, 20000, 50000, 100000]
    @entries = @release ? @release.entries.ordered : PriceListEntry.none
    @entry = PriceListEntry.new
  end

  # POST /price_lists/create_entry —— 增补行（仅最新批次）
  def create_entry
    release = PriceListRelease.latest || PriceListRelease.create!(released_at: Date.current)
    entry = release.entries.build(entry_params)
    entry.amended_at = Time.current

    if entry.save
      redirect_to price_lists_path, notice: "阶梯价已增补（#{entry.generic_part_no} #{entry.sell_by} #{entry.min_qty}+）。"
    else
      redirect_to price_lists_path, alert: entry.errors.full_messages.to_sentence
    end
  rescue ActiveRecord::RecordNotUnique
    redirect_to price_lists_path, alert: "该 (通用型号, 渠道, 数量档) 组合在当前批次已存在。"
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

  private

  def entry_params
    params.require(:price_list_entry).permit(:generic_part_no, :sell_by, :min_qty, :price)
  end
end
