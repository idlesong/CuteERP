class User < ActiveRecord::Base
  has_secure_password

  has_many :oppostatus

  validates :name, presence: true, uniqueness: true

  has_settings do |s|
    s.key :company, defaults: { name_en: "Wuxi Sicomm Communication Technologies, Inc.",
                                name_zh: "无锡士康通讯技术有限公司",
                                address_en: "F2, Building B, Changjiang Road, Wuxi, Jiangsu, China",
                                address_zh: "无锡市新吴区长江路21号B栋2楼",
                                telephone: "0510-66682208" }
    s.key :exchange_rate, defaults: { current_month: "6.3" }
    s.key :remark, defaults: { order_remark_en: "Unit price includes 13% VAT;",
                               order_remark_zh: "此价格包含13%增值税",
                               quotation_remark_en: "Unit price includes 13% VAT; Forbidden to re-sell;",
                               quotation_remark_zh: "单价包含13%增值税；禁止转卖，否则本公司有权取消特价" }
    s.key :step_values, defaults: { quantities: ["1", "1000", "2500", "5000", "10000", "20000", "50000", "100000"] }
    s.key :step_names, defaults: { names: ["step1", "step2", "step3", "step4", "step5", "step6", "step7", "step8",
                                           "step9", "step10", "step11", "step12", "step13", "step14", "step15", "step16"] }
    s.key :sell_by, defaults: { sell_by: ["OEM", "ODM"] }
  end

  # Kept for compatibility with the old login flow (sessions controller).
  def self.authenticate(name, password)
    find_by(name: name)&.authenticate(password)
  end
end
