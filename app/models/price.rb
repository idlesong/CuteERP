class Price < ApplicationRecord
  belongs_to :customer
  has_many :order_lines

  validates :customer_id, :customer_name, :part_number, :condition, :price, presence: true
  validates :price, numericality: { greater_than_or_equal_to: 0 }
  validates :condition, uniqueness: { scope: [:customer_name, :part_number] }
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

  def generate_price_number
    next_id = Price.where(created_at: DateTime.now.at_beginning_of_day..DateTime.now.at_end_of_day).count + 1
    "QO" + DateTime.now.strftime("%Y%m%d") + (next_id % 100).to_s.rjust(2, "0")
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
  def self.import(file)
    sheet = open_spreadsheet(file)
    each_data_row(sheet) do |row|
      number = row["Price_number"].to_s.strip
      next if number.blank?

      price = find_by(price_number: number) || new(price_number: number)
      import_customer = Customer.find_by(name: row["客户"].to_s.strip) ||
                        Customer.find_by(name_zh: row["客户"].to_s.strip)
      next if import_customer.nil?

      price.customer = import_customer
      price.customer_name = import_customer.name
      price.part_number = row["通用型号"].presence || price.part_number
      price.price = row["总单价"].presence || price.price
      price.base_price = row["芯片"].presence || price.base_price
      price.v1_price = row["声码1"].presence || price.v1_price
      price.v2_price = row["声码2"].presence || price.v2_price
      price.condition = row["订单量"].presence || price.condition
      price.remark = row["remark"].presence || price.remark
      price.currency = row["币别"].presence || price.currency
      # 状态列（生效/失效/...）映射回系统状态：生效=approved
      price.status = row["状态"] == "生效" ? "approved" : (row["状态"].presence || price.status)
      price.save!
    end
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
      yield row
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
    if (price.to_d - total.to_d).abs > 0.001
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
