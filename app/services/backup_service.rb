require "caxlsx"

# 备份归档（第二阶段 2.4）：
# - archive_month:  pg_dump 全库压缩 + 当月工作簿，归档到 storage/backups/
# - daily:          每日兜底 pg_dump（保留 30 天）
# - prune:          清理过期每日备份
class BackupService
  ARCHIVE_DIR = Rails.root.join("storage", "backups")

  def self.archive_month(month_date)
    dir = ARCHIVE_DIR
    FileUtils.mkdir_p(dir)
    stamp = month_date.strftime("%Y%m")

    dump_path = dir.join("cute_erp_closed_#{stamp}.sql.gz")
    dump(dump_path)

    workbook = MonthlyWorkbook.generate(month_date.beginning_of_month)
    xlsx_path = dir.join("cute_erp_closed_#{stamp}.xlsx")
    File.binwrite(xlsx_path, workbook)

    "归档文件 #{File.basename(dump_path)} + #{File.basename(xlsx_path)}"
  rescue StandardError => e
    Rails.logger.error("BackupService#archive_month failed: #{e.message}")
    raise
  end

  def self.daily
    dir = ARCHIVE_DIR
    FileUtils.mkdir_p(dir)
    dump(dir.join("cute_erp_daily_#{Date.current.strftime('%Y%m%d')}.sql.gz"))
    prune_daily
  end

  def self.prune_daily(keep_days = 30)
    cutoff = Date.current - keep_days
    Dir[ARCHIVE_DIR.join("cute_erp_daily_*.sql.gz")].each do |f|
      date_str = File.basename(f)[/\d{8}/]
      File.delete(f) if Date.parse(date_str) < cutoff
    end
  end

  def self.dump(path)
    sql_path = path.to_s.sub(/\.gz\z/, "")
    cfg = ActiveRecord::Base.connection_db_config.configuration_hash
    env = { "PGPASSWORD" => cfg[:password].to_s }
    ok = system(env, "pg_dump", "--no-password", "-U", cfg[:username].to_s,
                "-h", (cfg[:host] || "localhost").to_s, "-x", "-O",
                cfg[:database].to_s, out: sql_path, err: "/dev/null")
    raise "pg_dump 失败（数据库 #{cfg[:database]}）" unless ok

    system("gzip", "-f", sql_path) # 生成 .sql.gz
  end
end
