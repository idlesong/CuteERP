namespace :cute_erp do
  namespace :backup do
    desc "每日兜底备份：pg_dump 压缩归档，保留 30 天（配 systemd timer / cron）"
    task daily: :environment do
      BackupService.daily
      puts "daily backup done: #{BackupService::ARCHIVE_DIR}"
    end

    desc "月度归档：pg_dump + 当月工作簿（默认上月，可 MONTH=2026-09）"
    task monthly: :environment do
      month = ENV["MONTH"].present? ? Date.strptime(ENV["MONTH"], "%Y-%m") : Date.current.prev_month
      result = BackupService.archive_month(month.beginning_of_month)
      puts "monthly archive done: #{result}"
    end

    desc "清理过期每日备份（默认保留 30 天，KEEP_DAYS=60 可覆盖）"
    task prune: :environment do
      BackupService.prune_daily(ENV["KEEP_DAYS"].present? ? ENV["KEEP_DAYS"].to_i : 30)
      puts "pruned"
    end
  end
end
