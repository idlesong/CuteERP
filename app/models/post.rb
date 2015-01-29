class Post < ActiveRecord::Base
  attr_accessible :content, :subject, :title, :internal_url
  validates :internal_url, :uniqueness => true
end
