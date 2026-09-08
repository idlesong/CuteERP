class Post < ActiveRecord::Base
  validates :internal_url, uniqueness: true

  has_many :attachments, dependent: :destroy
end
