require 'test_helper'

class PriceTest < ActiveSupport::TestCase
  def setup
    @price = prices(:alpha)
  end

  # test validation
  # present: price, condition, part_number, customer_name, item_id, customer_id, 
  test "valid price with price, condition, part_number, customer_name" do
    assert @price.valid?, @price.errors.full_messages.to_s
  end

  test "invalid price without price" do
    @price.price = nil
    assert @price.invalid?    
    assert_equal [:price], @price.errors.keys    
  end
  
  test "invalid price without condition" do
    @price.condition = nil
    assert @price.invalid?
    assert_equal [:condition], @price.errors.keys
  end

  test "invalid price without part_number" do
    @price.part_number = nil
    assert @price.invalid?    
    assert_equal [:part_number], @price.errors.keys    
  end
  
  test "invalid price without customer_name" do
    @price.customer_name = nil
    assert @price.invalid?
    assert_equal [:customer_name], @price.errors.keys
  end  

  test "should not save price without nessary attribute" do
  	@price_new = Price.new
    assert @price_new.invalid?, @price_new.errors.full_messages.to_s
    assert_equal [:price, :condition, :part_number, :customer_name, :item_id, :customer_id], @price_new.errors.keys
  end

  # more logics
  test "assembled price should equal base plus extra price" do
    assert true
  end

  test "non-assembled price should equal to base price" do
    assert true
  end
end
