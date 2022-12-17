require 'test_helper'

class CustomerTest < ActiveSupport::TestCase
  def setup
    @customer = customers(:first)
  end

  # test validation
  # present: name, sales_type, payment, currency   
  test "valid customer with name, sales_type, payment, currency" do
    assert @customer.valid?, @customer.errors.full_messages.to_s
  end

  test "invalid customer without name" do
    @customer.name = nil
    assert @customer.invalid?    
    assert_equal [:name], @customer.errors.keys    
  end
  
  test "invalid customer without sales_type" do
    @customer.sales_type = nil
    assert @customer.invalid?
    assert_equal [:sales_type], @customer.errors.keys
  end

  test "invalid customer without payment" do
    @customer.payment = nil
    assert @customer.invalid?    
    assert_equal [:payment], @customer.errors.keys    
  end
  
  test "invalid customer without currency" do
    @customer.currency = nil
    assert @customer.invalid?
    assert_equal [:currency], @customer.errors.keys
  end  

  test "should not save customer without nessary attribute" do
  	@customer_new = Customer.new
    assert @customer_new.invalid?, @customer_new.errors.full_messages.to_s
    assert_equal [:name, :sales_type, :payment], @customer_new.errors.keys
    # bug: why don't show currency unique error?
  end

  test "customer name should be unique" do
    Customer.create(name: "clone_customer",  sales_type: 'OEM', payment: "COD", currency: "RMB")
    customer = Customer.new(name: "clone_customer",  sales_type: 'OEM', payment: "COD", currency: "RMB")
    assert customer.invalid?, customer.errors.full_messages.to_s
    assert_equal "已经被使用", customer.errors[:name].join(';')
  end
  
  test "customer should have disty" do
  end 

  test "import customer should skip customer with the same name " do
  end
end
