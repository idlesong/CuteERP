class Attachment < ActiveRecord::Base
  include DocumentAttachment

  belongs_to :post
end
