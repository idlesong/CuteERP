require 'test_helper'

class OrderTest < ActiveSupport::TestCase
  test "order attributes must not be empty" do
    order = Order.new
    # assert !order.save
    assert order.invalid?
  	assert order.errors[:name].any?, "Order must have contact name!"
    assert order.errors[:address].any?, "Order must have address!"
    assert order.errors[:pay_type].any?, "Order must have pay_type!"
    # assert order.errors[:order_number].any?, "Order must have order_number!"
  end

  test "order must belongs to a customer" do
  end

  test "dollar customer must input a exchange_rate" do
  end

end
