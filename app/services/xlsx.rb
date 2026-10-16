require "caxlsx"

# 极简 xlsx 生成器：单表/多表统一出口（下载附件用）
class Xlsx
  # sheets: [{ name:, headers:, rows: }]（rows 为数组的数组）
  def self.generate(sheets)
    sheets = [sheets] unless sheets.is_a?(Array) # 兼容单表哈希调用
    package = Axlsx::Package.new
    workbook = package.workbook
    style = workbook.styles.add_style(b: true, bg_color: "D9E1F2", alignment: { horizontal: :center })

    sheets.each do |sheet|
      workbook.add_worksheet(name: sheet[:name]) do |ws|
        ws.add_row(sheet[:headers], style: style)
        sheet[:rows].each { |row| ws.add_row(row) }
      end
    end
    package.to_stream.read
  end
end
