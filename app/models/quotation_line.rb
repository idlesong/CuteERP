# 报价单明细行：价格快照（生成/编辑时从 Price 复制，price_id 仅作追溯）
class QuotationLine < ApplicationRecord
  belongs_to :quotation
  belongs_to :price, optional: true
end
