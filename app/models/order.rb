# 客户订单：客户订单号（po_number）即单据主标识（P3 起取消内部编号）
# kind: normal/return（冲销，D1）；status: draft/submitted（草稿态，D10）
class Order < ApplicationRecord
  KINDS = %w[normal return].freeze
  STATUSES = %w[draft submitted].freeze
  PAYMENT_TYPES = ["款到发货", "T.T in advance", "COD", "T.T 30days"].freeze

  include ClosedPeriodGuard
  locks_closed_periods_on :created_at

  # 客户 PO 附件（PDF/图片），可多个；类型与大小校验见 documents_valid / ALLOWED_DOCUMENT_TYPES
  has_many_attached :documents
  validate :documents_valid

  ALLOWED_DOCUMENT_TYPES = %w[application/pdf image/png image/jpeg].freeze
  MAX_DOCUMENT_BYTES = 20.megabytes

  has_many :order_lines, -> { order(:line_no) }, dependent: :destroy
  belongs_to :customer
  belongs_to :end_customer, class_name: "Customer", optional: true

  validates :po_number, presence: true, uniqueness: { case_sensitive: false }
  validates :kind, inclusion: { in: KINDS }
  validates :status, inclusion: { in: STATUSES }
  validates :customer_id, :exchange_rate, presence: true

  before_validation :normalize_po_number
  before_destroy :ensure_not_issued, unless: :draft?

  scope :draft, -> { where(status: "draft") }
  scope :submitted, -> { where(status: "submitted") }
  scope :normal, -> { where(kind: "normal") }
  scope :ordered_by_po, -> { order(:po_number) }

  def draft? = status == "draft"

  def submitted? = status == "submitted"

  def return? = kind == "return"

  # 新单头：联系人/收发货信息从客户默认带出（发货时可改）
  def self.build_with_customer(customer, po_number: nil)
    new(customer: customer, po_number: po_number, pay_type: customer.payment,
        currency: customer.currency.presence || "RMB",
        name: customer.contact, address: customer.address, telephone: customer.telephone,
        ship_contact: customer.ship_contact, ship_address: customer.ship_address,
        ship_telephone: customer.ship_telephone)
  end

  # 汇率快照：RMB=1，外币取当月汇率
  def snapshot_exchange_rate!
    self.exchange_rate =
      if currency == "RMB"
        1
      else
        ExchangeRate.rate_for(Date.current, currency) || ExchangeRate.rate_for(Date.current, "USD") || 1
      end
  end

  def next_line_no
    (order_lines.maximum(:line_no) || 0) + 1
  end

  # 草稿 → 已提交；ODM 客户必须指定最终客户（D7）
  def submit!
    errors.add(:base, "订单没有行，不能提交") if order_lines.empty?
    errors.add(:base, "ODM 客户订单必须指定最终客户") if customer.sales_type == "ODM" && end_customer.nil?
    return false if errors.any?

    update(status: "submitted")
  end

  def total_price
    order_lines.sum(&:total_price)
  end

  def total_price_rmb
    (total_price * exchange_rate).round(2)
  end

  def not_issued?
    order_lines.joins(:production_allocations).none?
  end

  # 可编辑 = 未被生产订单签发（业界惯例：履约单据产生前可随意修改，签发后走冲销）
  def editable?
    not_issued?
  end

  EXPORT_HEADERS = %w[订单号 客户 最终客户 币别 汇率 状态 类型
                      行号 通用型号 芯片 声码1 声码2 数量 已分配 版本 要求交期 备注].freeze

  def self.export_rows
    includes(:order_lines, :customer, :end_customer).ordered_by_po.flat_map do |order|
      order.order_lines.map do |line|
        [order.po_number, order.customer.name_zh.presence || order.customer.name,
         order.end_customer&.name_zh.presence || order.end_customer&.name, order.currency,
         order.exchange_rate, order.status, order.kind,
         line.line_no, line.generic_part_no, line.base_price, line.v1_price, line.v2_price,
         line.quantity, line.allocated_qty, line.version, line.required_delivery_date&.to_date,
         line.remark]
      end
    end
  end

  def self.export_xlsx
    Xlsx.generate(name: "客户订单", headers: EXPORT_HEADERS, rows: export_rows)
  end

  private

  def documents_valid
    documents.each do |doc|
      unless doc.blob.content_type.in?(ALLOWED_DOCUMENT_TYPES)
        errors.add(:documents, "#{doc.filename}：仅支持 PDF/PNG/JPG")
      end
      if doc.blob.byte_size > MAX_DOCUMENT_BYTES
        errors.add(:documents, "#{doc.filename}：超过 20MB")
      end
    end
  end

  def normalize_po_number
    self.po_number = po_number.to_s.strip
  end

  # 已提交且已被生产订单签发的单不可删（草稿自由删）
  def ensure_not_issued
    return true if not_issued?

    errors.add(:base, "订单已被生产订单使用")
    throw :abort
  end
end
