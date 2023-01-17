require 'test_helper'

class LineItemTest < ActiveSupport::TestCase
  # present: price_id, quantity, Cart/Order/SalesOrder(line_id, line_type)

  test "line_item should save with nessary attribute" do
  	line_item = LineItem.new(line_number: "LO200001", fixed_price: 38, quantity: 10000, quantity_issued: 0)
    assert line_item.valid?, line_item.errors.full_messages.to_s
  end

  test "line_item should not save without nessary attributes" do
    line_item = LineItem.new
    assert line_item.invalid?, line_item.errors.full_messages.to_s
    # assert_equal [:fixed_price, :line_number, :quantity], line_item.errors.keys
    assert_equal [:fixed_price, :line_number], line_item.errors.keys
  end

end
