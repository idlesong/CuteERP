require "roo"

# 导入预检（两阶段导入的第一阶段）：
# - run:      在回滚事务中干跑导入器，收集 stats[:errors]/[:warnings]（不落任何数据）
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
      raise ActiveRecord::Rollback
    end
    Result.new(errors: collect(stats, "errors"), warnings: collect(stats, "warnings"))
  end

  def self.blocked?(result) = result.errors.any?

  # { "3" => ["消息"], "全局" => [...] }（按行归并，无行号的归入"全局"）
  def self.collect(stats, key)
    hash = {}
    Array(stats.stats[key]).each do |msg|
      row = msg[/第(\d+)行/, 1] || "全局"
      (hash[row] ||= []) << msg.sub(/\A第\d+行：/, "").sub(/\A第 \d+ 行：/, "")
    end
    hash
  end

  # 生成标注文件：末列「检查结果」= 错误/警告；另加「全局问题」表（如适用）
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

  # 标注文件落盘并返回 token（30 分钟有效；写入时顺带清理过期文件）
  def self.store_annotated(importer, file, result)
    FileUtils.mkdir_p(CHECK_DIR)
    token = SecureRandom.hex(10)
    File.binwrite(CHECK_DIR.join("#{token}.xlsx"), annotated_xlsx(importer, file, result))
    Dir.children(CHECK_DIR).each do |name|
      path = CHECK_DIR.join(name)
      File.delete(path) if File.mtime(path) < TOKEN_TTL.ago
    end
    token
  end

  def self.fetch_annotated(token)
    return nil unless token.to_s.match?(/\A[0-9a-f]{20}\z/)

    path = CHECK_DIR.join("#{token}.xlsx")
    path.exist? ? path : nil
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
