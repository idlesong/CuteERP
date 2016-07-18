require 'test_helper'

class CustomerTest < ActiveSupport::TestCase
  test "should not save without nessary attribute" do
  	customer = Customer.new
    assert customer.invalid?, customer.errors.full_messages.to_s
    assert_equal [:name, :payment], customer.errors.keys
    # bug: why don't show currency unique error?
  end

  test "should save with nessary attribute" do
  	customer = Customer.new(name: "测试客户1", payment: "COD", currency: "RMB")
    assert customer.valid?, customer.errors.full_messages.to_s
  end

  test "name should be unique" do
    Customer.create(name: "测试客户2",  payment: "COD", currency: "RMB")
    customer = Customer.new(name: "测试客户2", payment: "COD", currency: "RMB")
    assert customer.invalid?, customer.errors.full_messages.to_s
    assert_equal "has already been taken", customer.errors[:name].join(';')
  end
end
