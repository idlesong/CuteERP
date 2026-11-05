require "caxlsx"

# 备份归档（第二阶段 2.4）：
# - archive_month:  pg_dump 全库压缩 + 当月工作簿 + 当月内部对账单（四段，含排产核对），
#                   归档到 storage/backups/ —— 关账即留存一份核对过的月度数据快照
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

    st_xlsx = statement_xlsx(month_date.beginning_of_month)
    st_path = dir.join("cute_erp_statement_#{stamp}.xlsx")
    File.binwrite(st_path, st_xlsx)

    "归档文件 #{File.basename(dump_path)} + #{File.basename(xlsx_path)} + #{File.basename(st_path)}"
  rescue StandardError => e
    Rails.logger.error("BackupService#archive_month failed: #{e.message}")
    raise
  end

  # 当月内部对账单工作簿（四段：订单核对/出货核对/未交订单/排产核对；与导出同口径）
  def self.statement_xlsx(month_begin)
    statement = InternalMonthlyStatement.new(month_begin)
    rows_with_totals = lambda { |rows|
      result = []
      statement.totals_by_currency(rows).each do |cur, t|
        result += statement.to_rows(rows.select { |r| r.currency == cur })
        result << ["", "小计 #{cur} 客户", "", "", "", t[:qty], "", "", "",
                   t[:chip], t[:v1], t[:v2], t[:amount], "", t[:amount_rmb]]
      end
      t = statement.totals_for(rows)
      result << ["", "合计(折RMB)", "", "", "", t[:qty], "", "", "",
                 t[:chip_rmb], t[:v1_rmb], t[:v2_rmb], "", "", t[:amount_rmb]]
      result
    }
    Xlsx.generate([
      { name: "订单核对", headers: InternalMonthlyStatement::HEADERS, rows: rows_with_totals.call(statement.order_rows) },
      { name: "出货核对", headers: InternalMonthlyStatement::HEADERS, rows: rows_with_totals.call(statement.shipment_rows) },
      { name: "未交订单", headers: InternalMonthlyStatement::HEADERS, rows: rows_with_totals.call(statement.backlog_rows) },
      { name: "排产核对", headers: InternalMonthlyStatement::ALLOC_HEADERS, rows: statement.to_allocation_rows }
    ])
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
