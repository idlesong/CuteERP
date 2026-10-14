class ExchangeRate < ApplicationRecord
  validates :month, :currency, :rate, presence: true
  validates :currency, uniqueness: { scope: :month }

  scope :usd, -> { where(currency: "USD") }

  # 某月汇率（月首日定位），无记录返回 nil
  def self.rate_for(date, currency = "USD")
    where(currency: currency)
      .where(month: date.beginning_of_month)
      .order(:id).last&.rate
  end
end
