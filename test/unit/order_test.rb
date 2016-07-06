require 'test_helper'

class OrderTest < ActiveSupport::TestCase
  test "should not save order without nessary attributes" do
    # save: create, update; refer to validates
    order = Order.new
    # assert !order.save
    assert order.invalid?
  	assert order.errors[:name].any?, "Order must have contact name!"
    assert order.errors[:address].any?, "Order must have address!"
    assert order.errors[:pay_type].any?, "Order must have pay_type!"
    # assert order.errors[:order_number].any?, "Order must have order_number!"
    assert order.errors[:customer_id].any?, "Order must belongs_to a customer"
    assert order.errors[:exchange_rate].any?, "Orders must have exchange_rate for oversea customer"
    # Orders must have line_items
  end


  test "require item in cart" do
    get :new
    assert_redirected_to inventory_path
    assert_equal flash[:notice], 'Your cart is empty'
  end


  test "price must be special price or default price" do

  end

end
