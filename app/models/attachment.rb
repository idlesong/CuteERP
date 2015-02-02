class Attachment < ActiveRecord::Base
  attr_accessible :description, :name, :document

  validates_attachment :document, :content_type => {:content_type =>
    %w(image/jpeg image/jpg image/png application/pdf application/7-zip application/msword
    application/vnd.openxmlformats-officedocument.wordprocessingml.document)}
end
