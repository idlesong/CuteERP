class Price < ApplicationRecord
  belongs_to :customer
  has_many :order_lines

  validates :customer_id, :customer_name, :part_number, :condition, :price, presence: true
  validates :price, numericality: { greater_than_or_equal_to: 0 }
  # 同客户+同型号+同档位允许重新报价：导入端不自动替代旧价（仅警告，人工处理旧价失效），
  # 不再做 condition 唯一性校验；价格匹配（match_for）取生效日期最新的一条
  validates :currency, inclusion: { in: ["RMB", "USD"] }, allow_blank: true

  before_validation :parse_price_formula
  before_validation :normalize
  validate :components_sum_matches_price, if: -> { price.present? }
  before_destroy :ensure_not_approved
  before_destroy :ensure_not_used_by_others

  # 可用价（D8）：已批准（active 视同已批准）且在有效期内
  scope :available, -> {
    where(status: %w[approved active])
      .where("effective_from IS NULL OR effective_from <= ?", Date.current)
      .where("expired_at IS NULL OR expired_at >= ?", Date.current)
  }

  # 匹配一张可用报价（订单导入/UI 快照共用）：客户+型号 → 已批准 → 币别 →
  # 接收日期落在有效期内（as-of，支持补录历史订单）→ 数量档位取「订单量 ≤ 数量」的最高档，
  # 低于最小档取最低档（MOQ 价）；无数量或档位不可比时取生效日期最新的一条
  def self.match_for(customer: nil, part_number:, quantity: nil, date: Date.current, currency: nil)
    scope = where(part_number: part_number, status: %w[approved active])
    scope = scope.where(customer_id: customer.id) if customer
    scope = scope.where("currency = ? OR currency IS NULL OR currency = ''", currency) if currency.present?
    scope = scope.where("effective_from IS NULL OR effective_from <= ?", date)
                 .where("expired_at IS NULL OR expired_at >= ?", date)
    candidates = scope.order(effective_from: :desc, id: :desc).to_a
    return nil if candidates.empty?

    tiers = candidates.filter_map { |p| [numeric_condition(p), p] }.select { |c, _| c <= quantity.to_f }
    return tiers.max_by(&:first).last if tiers.any?

    with_tiers = candidates.filter_map { |p| [numeric_condition(p), p] }
    return with_tiers.min_by(&:first).last if with_tiers.any? && quantity.present?

    candidates.first
  end

  # 订单量档位 → 数值（纯数字可比；"1K" 等写法不参与档位比较）
  def self.numeric_condition(price)
    Float(price.condition.to_s.gsub(/[,\s]/, ""))
  rescue ArgumentError, TypeError
    nil
  end

  # 用报价的成分结构拆分一个总价：按 芯片/声码1/声码2 比例缩放，四舍五入尾差并入最大成分
  def split_amount(total)
    comps = [base_price, v1_price, v2_price].map { |c| c.to_s.to_d }
    sum = comps.sum
    return [total.to_d, 0.to_d, 0.to_d] if sum.zero?

    scaled = comps.map { |c| (total.to_d * c / sum).round(2) }
    gap = (total.to_d - scaled.sum).round(2)
    scaled[comps.index(comps.max)] += gap unless gap.zero?
    scaled
  end

  # 在有效期内（D8：默认空=不生效的补充：无日期限制视为长期有效）
  def in_valid_window?
    (effective_from.nil? || effective_from <= Date.current) &&
      (expired_at.nil? || expired_at >= Date.current)
  end

  # 生效 = 有效期内 + 已批准（active 为历史已批准状态，视同 approved）
  def effective?
    in_valid_window? && status.in?(%w[approved active])
  end

  # 过渡期：通用型号对应的官方 item（正式型号未建时为 nil，P3 起订单行直接用通用型号）
  def order_item
    Item.find_by(generic_part_no: part_number)
  end

  # 报价号：QO + 当日日期 + 3位流水（含占位0，如 QO20260310-011）
  # 删除后不重用流水号（按当日已占用号最大值递增，避免重号）
  def generate_price_number
    prefix = "QO#{Date.current.strftime('%Y%m%d')}-"
    used = Price.where("price_number LIKE ?", "#{prefix}%")
                .pluck(:price_number)
                .filter_map { |pn| pn[/\A#{prefix}(\d{3})\z/, 1]&.to_i }
    n = used.any? ? used.max + 1 : 1
    loop do
      candidate = format("%s%03d", prefix, n)
      break candidate unless Price.exists?(price_number: candidate)
      n += 1
    end
  end

  EXPORT_HEADERS = %w[报价号 客户 通用型号 芯片 声码1 声码2 总单价 订单量
                      生效日期 失效日期 币别 状态].freeze

  def self.export_rows(relation)
    relation.includes(:customer).order(:customer_name, :part_number, :condition).map do |pr|
      [pr.price_number, pr.customer_name, pr.part_number, pr.base_price, pr.v1_price,
       pr.v2_price, pr.price, pr.condition, pr.effective_from&.to_date,
       pr.expired_at&.to_date, pr.currency, pr.status]
    end
  end

  def self.export_xlsx(relation)
    Xlsx.generate(name: "价格", headers: EXPORT_HEADERS, rows: export_rows(relation))
  end

  # 按表头名称解析（对齐导出工作簿「价格」表；容忍空列/多余列/列序变化）
  # 与各导入服务同构的入口（导入预检/导入中心统一调用）
  def self.call(file, imported_by:, month: nil)
    import(file, imported_by: imported_by)
  end

  # 按表头名称解析（对齐导出工作簿「价格」表；容忍空列/多余列/列序变化）
  # 报价导入：输出 { created:, updated:, skipped:, errors:, warnings: } 校验报告
  # 客户不存在的行跳过并进错误（请先建客户档案再重新导入该行）
  def self.import(file, imported_by: nil)
    sheet = open_spreadsheet(file)
    created = updated = 0
    errors = []
    warnings = []

    each_data_row(sheet) do |row, i|
      number = row["Price_number"].to_s.strip
      if number.blank?
        if row.values.any? { |v| v.to_s.strip.present? }
          errors << "第#{i}行：Price_number 必填"
        end
        next
      end

      # 必填：客户/通用型号/总单价/订单量/芯片；声码1/声码2 可缺省（缺省并入芯片，D3）
      # 总单价为 =公式 时自动拆分，芯片亦豁免
      formula = row["总单价"].to_s.strip.start_with?("=")
      missing = %w[客户 通用型号 总单价 订单量].select { |h| row[h].to_s.strip.blank? }
      missing << "芯片" if row["芯片"].to_s.strip.blank? && !formula
      unless missing.empty?
        errors << "第#{i}行：缺少必填字段：#{missing.join('、')}"
        next
      end

      price = find_by(price_number: number) || new(price_number: number)
      import_customer = Customer.find_by(name: row["客户"].to_s.strip) ||
                        Customer.find_by(name_zh: row["客户"].to_s.strip)
      if import_customer.nil?
        errors << "第#{i}行：客户「#{row['客户']}」不存在"
        next
      end

      is_new = price.new_record?
      price.customer = import_customer
      price.customer_name = import_customer.name
      price.part_number = row["通用型号"].presence || price.part_number
      price.effective_from = row["生效日期"].presence || price.effective_from
      price.expired_at = row["失效日期"].presence || price.expired_at
      raw_total = row["总单价"].to_s.strip
      price.price = raw_total.start_with?("=") ? raw_total : (raw_total.presence&.to_d&.round(2) || price.price)
      price.condition = row["订单量"].presence || price.condition
      price.remark = row["remark"].presence || price.remark
      price.currency = row["币别"].presence || price.currency
      # 价格表 = 已确认的价格：默认 approved；无法识别的状态值也按已批准导入
      st = row["状态"].to_s.strip
      price.status = %w[approved active requested].include?(st) ? st : "approved"

      # 成分取 Excel 显示值（2 位小数）：消除单元格隐藏小数位导致的看起来合计相等却报错
      chip = row["芯片"].presence&.to_d&.round(2)
      v1 = row["声码1"].presence&.to_d&.round(2)
      v2 = row["声码2"].presence&.to_d&.round(2)
      if chip # 尾差并入芯片，保证成分合计 = 总单价（各自四舍五入可能产生 ±0.01）
        diff = price.price.to_d - [chip, v1 || 0.to_d, v2 || 0.to_d].sum
        chip = (chip + diff).round(2)
      end
      price.base_price = chip.presence || price.base_price
      price.v1_price = v1.presence || price.v1_price
      price.v2_price = v2.presence || price.v2_price

      # 同客户+同型号+同档位已有未过期价格：**不自动替代**（人工在价格列表处理旧价失效），
      # 仅提示警告供复核。新价生效优先由 match_for 的「生效日期最新」规则自然保证
      if is_new
        new_eff = price.effective_from || Date.current
        dup = where(customer_name: import_customer.name, part_number: price.part_number,
                    condition: price.condition).where.not(id: price.id)
                  .where("expired_at IS NULL OR expired_at >= ?", new_eff)
                  .order(:id).first
        if dup
          warnings << "第#{i}行：同客户+型号+档位已有未过期价格 #{dup.price_number}" \
                      "（原价 #{dup.price}，失效日 #{dup.expired_at || '长期有效'}），未自动替代，请人工复核"
        end
      end

      price.save!
      is_new ? created += 1 : updated += 1
    rescue ActiveRecord::RecordInvalid => e
      errors << "第#{i}行：#{e.message}"
    end

    Import.create!(kind: "prices", filename: file.original_filename,
                   imported_by: imported_by,
                   stats: { created: created, updated: updated, errors: errors, warnings: warnings })
  end
  # 通用：按表头名称逐行解析（跳过空表头列），容忍列序变化/多余列
  def self.each_data_row(sheet, &block)
    headers = (1..sheet.last_column).map { |c| sheet.cell(1, c).to_s.strip }
    (2..sheet.last_row).each do |i|
      row = {}
      headers.each_with_index do |h, ci|
        next if h.empty?

        row[h] = sheet.cell(i, ci + 1)
      end
      yield row, i
    end
  end

  def self.open_spreadsheet(file)
    sheet = case File.extname(file.original_filename)
            when ".csv" then Roo::CSV.new(file.path)
            when ".xls" then Roo::Excel.new(file.path, file_warning: :ignore)
            when ".xlsx" then Roo::Excelx.new(file.path, file_warning: :ignore)
            else raise "Unknown file type: #{file.original_filename}"
            end
    sheet.default_sheet = "价格" if sheet.sheets.include?("价格")
    sheet
  end

  private

  # 成分公式："=50+50" → 总价 100，成分按顺序拆为 基本款/附加1/附加2（多余并入附加2）
  def self.parse_formula_terms(input)
    expr = input.to_s.strip.sub(/\A=/, "").gsub(/\s+/, "")
    return nil if expr.blank?
    return nil unless expr.match?(/\A\d+(?:\.\d+)?(?:\+\d+(?:\.\d+)?)*\z/)

    terms = expr.split("+").map(&:to_f)
    terms << (terms.pop + terms.pop) while terms.size > 3
    terms
  end

  def parse_price_formula
    raw = price_before_type_cast
    return unless raw.is_a?(String) && raw.strip.start_with?("=")

    terms = self.class.parse_formula_terms(raw)
    if terms.nil?
      errors.add(:price, "公式格式无法识别（示例：=50+50，仅支持加法）")
      return
    end

    self.price = terms.sum.round(2)
    self.base_price = terms[0] || 0
    self.v1_price = terms[1] || 0
    self.v2_price = terms[2] || 0
  end

  def normalize
    self.part_number = part_number.presence
    self.currency = currency.presence || "RMB"
    self.status = status.presence || "requested"
    self.base_price = base_price.presence
    self.v1_price = v1_price.presence
    self.v2_price = v2_price.presence
    # 成分均空时，全额计入基本款（D3：可不区分）
    if price.present? && base_price.blank? && v1_price.blank? && v2_price.blank?
      self.base_price = price
    end
  end

  def components_sum_matches_price
    return if [base_price, v1_price, v2_price].all?(&:blank?)

    total = [base_price, v1_price, v2_price].compact.sum
    if (price.round(2) - total.round(2)).abs > 0.005 # 容差吸收显示舍入（Excel 隐藏小数位）
      errors.add(:price, "必须等于 基本款 + 附加1 + 附加2（当前合计 #{total}）")
    end
  end

  def ensure_not_approved
    return unless status_was == "approved"

    errors.add(:base, "price has been approved, cannot update!")
    throw :abort
  end

  def ensure_not_used_by_others
    return if order_lines.empty?

    errors.add(:base, "order_lines exist")
    throw :abort
  end
end
