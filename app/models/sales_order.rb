# 生产订单（六联单）：XS{yyyy}-{年内流水}；行 = production_lines（正式型号）
# 需求来源：production_allocations 台账（D2）；发货 = shipments（可多次，末次派生发货时间）
class SalesOrder < ApplicationRecord
  belongs_to :customer
  belongs_to :end_customer, class_name: "Customer", optional: true
  has_many :production_lines, dependent: :destroy
  has_many :shipments, dependent: :destroy

  include DocumentAttachment

  validates :serial_number, presence: true, uniqueness: true
  validates :bill_address, :bill_contact, :bill_telephone, :ship_contact, :ship_address,
            :ship_telephone, presence: true
  validates :customer_id, :payment_term, presence: true
  validates :exchange_rate, presence: true
  validates :production_lines, presence: true, on: :create

  before_validation :generate_serial_number, on: :create, if: -> { serial_number.blank? }

  # 单头初始化：账单/收货信息从客户默认带出
  def initialize_order_header(new_customer)
    self.customer = new_customer
    self.end_customer ||= new_customer
    self.payment_term = new_customer.payment
    self.bill_contact = new_customer.contact
    self.bill_address = new_customer.address
    self.bill_telephone = new_customer.telephone
    self.ship_contact = new_customer.ship_contact
    self.ship_address = new_customer.ship_address
    self.ship_telephone = new_customer.ship_telephone
  end

  # 汇率快照：RMB=1，外币取当月汇率
  def snapshot_exchange_rate!
    self.exchange_rate =
      if customer.currency == "RMB"
        1
      else
        ExchangeRate.rate_for(Date.current, customer.currency) ||
          ExchangeRate.rate_for(Date.current, "USD") || 1
      end
  end

  # XS{yyyy}-{年内流水}（XS2026-192，流水按年重置；唯一索引 + rescue 兜底并发）
  def generate_serial_number
    year = Date.current.year
    seq = self.class.where(created_at: Time.zone.local(year)..).count + 1
    self.serial_number = "XS#{year}-#{seq}"
  end

  # 发货时间 = 末次出库单（派生，不再落列）
  def delivery_date
    shipments.order(:shipped_at).last&.shipped_at
  end

  def shipped?
    delivery_date.present?
  end

  def total_price
    production_lines.sum(&:total_price)
  end

  before_destroy :ensure_not_shipped

  private

  def ensure_not_shipped
    return if delivery_date.nil?

    errors.add(:base, "already invoiced or delivered")
    throw :abort
  end
end
