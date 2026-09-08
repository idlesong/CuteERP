class LineItem < ActiveRecord::Base
  validates :fixed_price, presence: true, numericality: { greater_than_or_equal_to: 0 }
  validates :quantity, presence: true, numericality: { greater_than_or_equal_to: 1 }
  validates :line_number, presence: true
  # validates :line_number, uniqueness: true
  # validates :quantity_issued, numericality: { less_than_or_equal_to: :quantity }

  belongs_to :line, polymorphic: true
  belongs_to :item
  belongs_to :price
  belongs_to :cart

  # default price is in RMB, currency_price:exchange_with_tax
  def show_currency_price(exchange_rate, customer_currency)
    if customer_currency == "USD"
      fixed_price / 1.13 / exchange_rate
    else
      fixed_price
    end
  end

  def total_price
    fixed_price.nil? ? 0 : fixed_price * quantity
  end

  def total_currency_price(exchange_rate, customer_currency)
    show_currency_price(exchange_rate, customer_currency) * quantity
  end
end
