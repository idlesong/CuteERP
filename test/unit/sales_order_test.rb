require 'test_helper'

class SalesOrderTest < ActiveSupport::TestCase
  test "should not save order without nessary attributes" do
    sales_order = SalesOrder.new
    assert_not sales_order.valid?
    assert_equal [:serial_number, :customer_id, :bill_address, :bill_contact,
      :bill_telephone, :ship_contact, :ship_address, :ship_telephone, :exchange_rate]
      sales_order.errors.keys
  end

  test "dollar customer must input a exchange_rate" do
  end
end
