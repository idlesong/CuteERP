require 'test_helper'

class ItemTest < ActiveSupport::TestCase
  # test "the truth" do
  #   assert true
  # end
  test "item attributes must not be empty" do
  	item = Item.new
  	assert item.invalid?
  	assert item.errors[:name].any?
    assert item.errors[:partNo].any?
  	# assert item.errors[:package].any?
  	#assert item.errors[:price].any?
  end

  test "item price must be positive" do
  	item = Item.new(:name => "SRT3241",
  					:package => "QFN48",
  					:imageURL => "rails.png")
  	item.price = -1
  	assert item.invalid?
  	assert_equal "must be greater than or equal to 0.01",
  		item.errors[:price].join(';')

    item.price = 0
    assert item.invalid?
    assert_equal "must be greater than or equal to 0.01",
      item.errors[:price].join(';')

  	item.price = 1
  	assert item.invalid?
  end

  def new_item(image_URL)
  	Item.new(:name  => "PA SCT3604",
  			 :package => "QFN24",
  			 :price => 4,
  			 :partNo => "SCT3604",
  			 :imageURL => image_URL)
  end

  test "image url" do
  	ok = %w{fred.gif fred.png FRED.JPG FRED.Jpg
  			http://a.b.c/x/y/z/fred.gif}

  	bad = %w{ fred.doc fred.gif/more fred.gif.more }

  	ok.each do |name|
  		assert new_item(name).valid?, "#{name} shouldn't be invalid"
  	end

  	# bad.each do |name|
  	# 	assert new_item(name).invalid?, "#{name} shouldn't be valid"
  	# end
  end


end
