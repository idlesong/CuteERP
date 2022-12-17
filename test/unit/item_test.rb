require 'test_helper'

class ItemTest < ActiveSupport::TestCase
  def setup  
    @input_attributes = {name: "new_item", partNo: "new_partNo", assembled: "yes"}
    @more_input_attributes = {name: "more_item", partNo: "more_partNo"}
    @item = Item.create(@input_attributes)    
    @item_one = items(:one)
  end

  # test validation
  # present: name, partNo
  test "valid item with name and partNo" do
    assert @item.valid?, @item.errors.full_messages.to_s
  end

  test "invalid item without name" do
    @item.name = nil
    assert @item.invalid?    
    assert_equal [:name], @item.errors.keys    
  end
  
  test "invalid item without partNo" do
    @item.partNo = nil
    assert @item.invalid?
    assert_equal [:partNo], @item.errors.keys
  end  

  test "partNo should be unique" do
    #@input.attributes has been taken by @item
    item = Item.new(@input_attributes)
    assert item.invalid?, item.errors.full_messages.to_s
    assert_equal "已经被使用", item.errors[:partNo].join(';')
  end

  test "assembled item should include base and extra_item" do
    # item = Item.create(name: "功率放大器", partNo: "SCT3258TD")
  end 

  # test associations/ includes? size?
  # item has many: orders, line_items, prices, set_prices
  # test '#orders' do
  #   assert_equal 2, @item.orders.size
  # end

  # test '#line_items' do
  #   assert_equal 2, @item.line_items.size
  # end

  # test '#prices' do
  #   assert_equal 2, @item.prices.size
  # end  

  # test '#set_prices' do
  #   assert_equal 2, @item.set_prices.size
  # end 

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
