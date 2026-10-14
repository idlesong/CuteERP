class PriceListRelease < ApplicationRecord
  has_many :entries, class_name: "PriceListEntry", dependent: :destroy

  validates :released_at, presence: true

  scope :ordered, -> { order(released_at: :desc, id: :desc) }

  def self.latest
    ordered.first
  end
end
