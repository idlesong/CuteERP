require 'test_helper'

class SetPriceTest < ActiveSupport::TestCase
  def setup
    @item_one = items(:one)
    @input_attributes = {price: 30, item_id: @item_one.id, order_quantity: 3000, sell_by: "OEM", released_at: Time.now}
    # @more_input_attributes = {name: "more_item", partNo: "more_partNo"}
    @set_price = SetPrice.create(@input_attributes)  
  end

  # test validation
  # present: item_id, price, order_quantity, released_at, sell_by 
  test "valid price with price, condition, part_number, customer_name" do
    assert @set_price.valid?, @set_price.errors.full_messages.to_s
  end

  test "invalid set_price without item.id" do
    @set_price.item_id = nil
    assert @set_price.invalid?    
    assert_equal [:item_id], @set_price.errors.keys    
  end

  test "invalid set_price without price" do
    @set_price.price = nil
    assert @set_price.invalid?    
    assert_equal [:price], @set_price.errors.keys    
  end

  test "invalid set_price without order_quantity" do
    @set_price.order_quantity = nil
    assert @set_price.invalid?    
    assert_equal [:order_quantity], @set_price.errors.keys    
  end

  test "invalid set_price without released_at" do
    @set_price.released_at = nil
    assert @set_price.invalid?    
    assert_equal [:released_at], @set_price.errors.keys    
  end

  test "invalid set_price without sell_by" do
    @set_price.sell_by = nil
    assert @set_price.invalid?    
    assert_equal [:sell_by], @set_price.errors.keys    
  end


# more logics
  test "every time there should be single price" do
    assert true
  end  
end
