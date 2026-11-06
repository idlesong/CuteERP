require "roo"

# 导入预检（两阶段导入的第一阶段）：
# - run:      在回滚事务中干跑导入器，收集 stats[:errors]/[:warnings]（不落任何数据）；
#             干跑末尾做**汇总校验**（control totals）：Excel 有效行数/数量合计/金额合计
#             vs 实际导入行数/系统数量/系统金额——不一致追加 errors 阻断导入
#             （抓行级校验抓不到的「静默不一致」：如核销覆盖丢行、行静默丢失）
# - blocked?: errors 非空则禁止导入；warnings 不阻断
# - annotated_xlsx: 原表末尾追加「检查结果」列，逐行写入错误/警告，供修正后重新导入
module ImportChecker
  CHECK_DIR = Rails.root.join("tmp/import_checks")
  TOKEN_TTL = 30.minutes

  Result = Struct.new(:errors, :warnings, keyword_init: true)

  def self.run(importer, file, month: nil)
    stats = nil
    ActiveRecord::Base.transaction do
      # 干跑不产生批次记录，但 Import.imported_by 非空约束需占位用户（事务结束即回滚）
      stats = importer.call(file, imported_by: User.order(:id).first, month: month)
      control_totals(stats) # 汇总校验（仅 errors 为空时有意义；不一致追加 errors → 阻断）
      raise ActiveRecord::Rollback
    end
    Result.new(errors: collect(stats, "errors"), warnings: collect(stats, "warnings"))
  end

  def self.blocked?(result) = result.errors.any?

  # 汇总校验（control totals）：导入器在 stats[:control] 汇报
  # { excel_rows:, rows:, excel_qty:, qty:, excel_amount:, amount: }（数量/金额可缺省）。
  # 全部行级 errors 为空时才校验（有错误行未导入时差异必然存在，无信息量）；
  # 不一致 → 追加全局 errors → 阻断导入。
  # stats 可为 Import 对象（真实批次）或 Hash（干跑返回），两种形态兼容读取
  def self.control_totals(stats)
    st = stats.respond_to?(:stats) ? (stats.stats || {}) : stats
    return if st["errors"].present? || st[:errors].present?

    c = (st["control"] || st[:control])&.symbolize_keys # jsonb 序列化后键为字符串，归一为符号
    return unless c

    e = st["errors"] || st[:errors]
    if c[:rows] && c[:excel_rows] != c[:rows]
      e << "汇总不一致：Excel 有效数据行 #{c[:excel_rows]} 行 vs 实际导入 #{c[:rows]} 行" \
           "（可能存在静默覆盖或丢失，请逐行核对）"
    end
    if c[:qty] && c[:excel_qty] != c[:qty]
      e << "汇总不一致：数量合计 Excel #{c[:excel_qty]} vs 导入后 #{c[:qty]}" \
           "（差 #{c[:qty] - c[:excel_qty]}，请逐行核对）"
    end
    if c[:amount] && (c[:amount].to_d - c[:excel_amount].to_d).abs > 0.01
      e << "汇总不一致：金额合计 Excel #{c[:excel_amount]} vs 导入后 #{c[:amount]}" \
           "（差 #{(c[:amount].to_d - c[:excel_amount].to_d).round(2)}，请逐行核对）"
    end
    nil
  end

  # { "3" => ["消息"], "全局" => [...] }（按行归并，无行号的归入"全局"；行号容忍空格）
  def self.collect(stats, key)
    hash = {}
    Array(stats.stats[key]).each do |msg|
      row = msg[/第\s*(\d+)\s*行/, 1] || "全局"
      (hash[row] ||= []) << msg.sub(/\A第\s*\d+\s*行：/, "")
    end
    hash
  end

  # 生成标注文件：末列「检查结果」= 错误/警告；另加「全局问题」表（如适用）
  # 文件名含导入类型（客户订单/六联单…），避免多类型标注混淆
  def self.annotated_xlsx(importer, file, result)
    sheet = importer.open_spreadsheet(file)
    headers = (1..sheet.last_column).map { |c| sheet.cell(1, c).to_s.strip } + ["检查结果"]

    package = Axlsx::Package.new
    wb = package.workbook
    head_style = wb.styles.add_style(b: true, bg_color: "D9E1F2")
    wb.add_worksheet(name: sheet.default_sheet) do |ws|
      ws.add_row(headers, style: head_style)
      (2..sheet.last_row).each do |i|
        row = (1..sheet.last_column).map { |c| cell_text(sheet.cell(i, c)) }
        row << messages_for(result, i)
        ws.add_row(row)
      end
    end
    if result.errors["全局"] || result.warnings["全局"]
      wb.add_worksheet(name: "全局问题") do |ws|
        ws.add_row(["检查结果"], style: head_style)
        (result.errors["全局"].to_a + result.warnings["全局"].to_a).each { |m| ws.add_row([m]) }
      end
    end
    package.to_stream.read
  end

  # 标注文件落盘并返回 token（30 分钟有效；写入时顺带清理过期文件）。
  # 文件名带导入类型（如 CustomerOrders-<token>.xlsx），下载时 likewise 带类型，避免多类型标注混淆
  def self.store_annotated(importer, file, result)
    FileUtils.mkdir_p(CHECK_DIR)
    token = SecureRandom.hex(10)
    kind = importer.name.sub(/Import\z/, "")
    File.binwrite(CHECK_DIR.join("#{kind}-#{token}.xlsx"), annotated_xlsx(importer, file, result))
    Dir.children(CHECK_DIR).each do |name|
      path = CHECK_DIR.join(name)
      File.delete(path) if File.mtime(path) < TOKEN_TTL.ago
    end
    token
  end

  def self.fetch_annotated(token)
    return nil unless token.to_s.match?(/\A[A-Za-z]+-[0-9a-f]{20}\z/)

    path = CHECK_DIR.glob("*#{token}.xlsx").first
    path&.exist? ? path : nil
  end

  def self.messages_for(result, row)
    msgs = []
    result.errors[row.to_s].to_a.each { |m| msgs << "错误：#{m}" }
    result.warnings[row.to_s].to_a.each { |m| msgs << "警告：#{m}" }
    msgs.join("；")
  end

  def self.cell_text(cell)
    cell.is_a?(Date) || cell.is_a?(Time) ? cell.to_date.to_s : cell.to_s
  end
end
