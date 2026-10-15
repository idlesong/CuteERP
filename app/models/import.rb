# 导入批次（第二阶段 2.2）
class Import < ApplicationRecord
  belongs_to :imported_by, class_name: "User"

  def report_summary
    "新建 #{stats['created']} / 更新 #{stats['updated']} / 跳过 #{stats['skipped']}"
  end
end
