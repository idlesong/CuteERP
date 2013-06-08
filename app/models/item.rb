class Item < ActiveRecord::Base
  attr_accessible :imageURL, :name, :package, :partNo, :price
end
