require 'test_helper'

class SalesOrderTest < ActiveSupport::TestCase
  # test validation: serial_number,customer_id,payment_term,line_items,exchange_rate
  #                bill_contact,bill_address,bill_telephone
  #                ship_contact, ship_address, ship_telephone,
  test "should not save sales order without nessary attributes" do
    sales_order = SalesOrder.new
    assert sales_order.invalid?
    assert_equal [:serial_number, 
                :bill_address, :bill_contact, :bill_telephone, 
                :ship_contact, :ship_address, :ship_telephone, 
                :customer_id, :payment_term, :line_items, :exchange_rate],
            sales_order.errors.keys
  end

  test "dollar customer must input a exchange_rate" do
  end
end
