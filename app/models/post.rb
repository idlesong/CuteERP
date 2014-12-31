class Post < ActiveRecord::Base
  attr_accessible :content, :subject, :title
end
