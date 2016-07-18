require 'test_helper'

class ItemTest < ActiveSupport::TestCase

  test "should not save without nessary attribute" do
  	item = Item.new
    assert item.invalid?
    assert_equal [:name, :partNo, :price], item.errors.keys
  end

  test "should save with nessary attribute" do
  	item = Item.new(name: "高效率功率放大器", partNo: "SCT3604A", price: 3)
    assert item.valid?, item.errors.full_messages.to_s
  end

  test "partNo should be unique" do
    item = Item.create(name: "功率放大器", partNo: "S3604", price: 5)
    item = Item.new(name: "功率放大器", partNo: "S3604", price: 5)
    assert item.invalid?, item.errors.full_messages.to_s
    assert_equal "has already been taken", item.errors[:partNo].join(';')
  end

  test "price should greate than or equal to 0" do
  	item = Item.new(name: "高效率功率放大器", partNo: "SCT3604B")
  	item.price = -1

  	assert item.invalid?
  	assert_equal "must be greater than or equal to 0", item.errors[:price].join(';')

    item.price = 0
    assert item.valid?, item.errors.full_messages.to_s

  	item.price = 1
  	assert item.valid?, item.errors.full_messages.to_s
  end



  # test "image url" do
  # 	ok = %w{fred.gif fred.png FRED.JPG FRED.Jpg
  # 			http://a.b.c/x/y/z/fred.gif}
  #
  # 	bad = %w{ fred.doc fred.gif/more fred.gif.more }
  #
  # 	ok.each do |name|
  # 		assert new_item(name).valid?, "#{name} shouldn't be invalid"
  # 	end
  #
  # 	# bad.each do |name|
  # 	# 	assert new_item(name).invalid?, "#{name} shouldn't be valid"
  # 	# end
  # end


end
