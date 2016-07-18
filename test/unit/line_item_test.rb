require 'test_helper'

class LineItemTest < ActiveSupport::TestCase
  test "line_item should not save without nessary attributes" do
    line_item = LineItem.new
    assert line_item.invalid?, line_item.errors.full_messages.to_s
    assert_equal [:price, :quantity], line_item.errors.keys
  end

  test "line_item should save with nessary attribute" do
  	line_item = LineItem.new(price: 38, quantity: 10000, quantity_issued: 0)
    assert line_item.valid?, line_item.errors.full_messages.to_s
  end


end
