require 'test_helper'

class LineItemTest < ActiveSupport::TestCase
  test "line item attributes must not be empty" do
    line_item = LineItem.new
  	assert line_item.invalid?
  	assert line_item.errors[:item_id].any?
    assert line_item.errors[:quantity].any?
  end

  test "quantity should more than zero" do
  end

  test "price must greater than zero" do
  end
end
