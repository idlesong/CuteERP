require 'test_helper'

class OrderTest < ActiveSupport::TestCase
  test "order should not save without nessary attributes" do
    # save: create, update; refer to validates
    order = Order.new
    assert_not order.valid?
    assert_equal [:order_number, :customer_id, :pay_type,:exchange_rate], order.errors.keys
    # Orders must have line_items
  end
    
  test "order should save with nessary attributes" do
    order = Order.create(order_number: 'PO201601', customer_id: 1, pay_type: 'COD',
        exchange_rate: 6.5);
    assert order.valid?, "Order was not valid, when all nessary attributes supplied"
    assert_equal 'PO201601', order.order_number, 'Order number does not match'
    assert_equal 1, order.customer.id, 'Order customer_id does not match'
    assert_equal 'COD', order.pay_type, 'Order pay_type does not match'
    assert_equal 6.5, order.exchange_rate, 'Order exchange_rate does not match'
  end

  test "require item in cart" do
    get :new
    assert_redirected_to inventory_path
    assert_equal flash[:notice], 'Your cart is empty'
  end


  test "price must be special price or default price" do
  end

end
