require 'digest/sha2'

class User < ActiveRecord::Base
  attr_accessible :password, :name, :password_confirmation,:email, :telephone, :group
  validates :name, :presence => true, :uniqueness => true

  validates :password, :confirmation => true
  attr_accessor :password_confirmation
  attr_reader   :password

  validate :password_must_be_present

  has_many :oppostatus

  has_settings do |s|
    s.key :company, :defaults => { :name_en => "Wuxi Sicomm Communication Technologies, Inc.",
                                   :name_zh => "无锡士康通讯技术有限公司",
                                   :address_en => "F2, Building B, Changjiang Road, Wuxi, Jiangsu, China",
                                   :address_zh => "无锡市新吴区长江路21号B栋2楼",
                                   :telephone => "0510-66682208" }
    s.key :exchange_rate, :defaults => { :current_month => "6.3" }   
    s.key :remark, :defaults => { :order_remark_en => "Unit price includes 13% VAT;",
                                  :order_remark_zh => "此价格包含13%增值税",
                                  :quotation_remark_en => "Unit price includes 13% VAT; Forbidden to re-sell;",
                                  :quotation_remark_zh => "单价包含13%增值税；禁止转卖，否则本公司有权取消特价",}
    s.key :step_values, :defaults => { :quantities => ["1", "1000", "2500", "5000", "10000",  "20000", "50000", "100000"] }
    s.key :step_names, :defaults => { :names => ["step1", "step2", "step3", "step4", "step5",  "step6", "step7", "step8",
                                          "step9", "step10", "step11", "step12", "step13", "step14", "step15", "step16"]}
    s.key :sell_by, :defaults => { :sell_by => ["OEM", "ODM"] }                                                             
  end

  def User.encrypt_password(password, salt)
  	Digest::SHA2.hexdigest(password + "wibble" + salt)
  end

  def generate_salt
  	self.salt = self.object_id.to_s + rand.to_s
  end

  #password is vistual attribute
  def password=(password)
  	@password = password

  	if password.present?
  		generate_salt
  		self.hashed_password = self.class.encrypt_password(password, salt)
  	end
  end

  def User.authenticate(name, password)
  	if user = find_by_name(name)
  		if user.hashed_password == encrypt_password(password, user.salt)
  			user
  		end
  	end
  end

  private
  def password_must_be_present
  	errors.add(:password, "Missing password") unless hashed_password.present?
  end

end
