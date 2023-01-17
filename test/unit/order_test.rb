require 'test_helper'

class OrderTest < ActiveSupport::TestCase
  def setup  
    @customer = customers(:first)
    @order_attributes = {
      order_number: "PO20221212", 
      customer_id: @customer.id,
      pay_type: "COD",
      exchange_rate: 1,
    }
    @line_attributes = {
      fixed_price: 38, line_number: "LONew001", quantity: 10000, quantity_issued: 0
    }
    @order = Order.new(@order_attributes)    
    @order.line_items.new(@line_attributes)
    @order.save
  end

  # test validation
  # present: order_number, customer_id, pay_type, line_items, exchange_rate
  test "order should save with nessary attributes" do
    assert @order.valid?, @order.errors.full_messages.to_s
  end

  test "order should not save without nessary attributes" do
    # save: create, update; refer to validates
    @new_order = Order.new
    assert_not @new_order.valid?
    assert_equal [:order_number, :pay_type, :line_items, :customer_id, :exchange_rate], @new_order.errors.keys
    # Orders must have line_items
  end

  test "price must be special price or default price" do
  end

end
