class ExchangeRate < ApplicationRecord
  validates :month, :currency, :rate, presence: true
  validates :currency, uniqueness: { scope: :month }

  before_validation :normalize_month

  scope :usd, -> { where(currency: "USD") }

  # 某月汇率（月首日定位），无记录返回 nil
  def self.rate_for(date, currency = "USD")
    where(currency: currency)
      .where(month: date.beginning_of_month)
      .order(:id).last&.rate
  end

  private

  # 兼容 "2026/10"、"2026-10"、"2026-10-1" 等写法，统一为当月首日
  def normalize_month
    raw = month_before_type_cast
    return if raw.blank? || !raw.is_a?(String)

    m = raw.strip.match(/\A(\d{4})[-\/.](\d{1,2})/)
    self.month = Date.new(m[1].to_i, m[2].to_i, 1) if m
  end
end
