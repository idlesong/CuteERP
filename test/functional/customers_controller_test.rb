require 'test_helper'

class CustomersControllerTest < ActionController::TestCase
  setup do
    @input_attributes = {name: "new_customer", sales_type: "OEM", payment: "COD", currency: "RMB"}
    @more_input_attributes = {name: "one_more_customer", sales_type: "OEM", payment: "COD", currency: "RMB"}
    @customer = Customer.create(@input_attributes)
    @customer1st = customers(:first)
  end

  test "should get index" do
    get :index
    assert_response :success
    assert_not_nil assigns(:customers)
  end

  test "should get new" do
    get :new
    assert_response :success
  end

  test "should create customer" do
    assert_difference('Customer.count') do
      post :create, customer: @more_input_attributes
    end

    assert_redirected_to customer_path(assigns(:customer))
  end

  test "should not create customer with the same name" do
    assert_no_difference('Customer.count') do
      # @input_attributes has been taken by @customer
      post :create, customer: @input_attributes
    end

    # assert_redirected_to customer_path(assigns(:customer))
  end

  test "should show customer" do
    get :show, id: @customer
    assert_response :success
  end

  test "should get edit" do
    get :edit, id: @customer
    assert_response :success
  end

  test "should update customer" do
    put :update, id: @customer, customer: { 
      address: @customer.address, 
      balance: @customer.balance, 
      contact: @customer.contact, 
      name: @customer.name, 
      since: @customer.since, 
      telephone: @customer.telephone }
    assert_redirected_to customer_path(assigns(:customer))
  end

  test "should destroy customer has not been used" do
    assert_difference('Customer.count', -1) do
      delete :destroy, id: @customer
    end

    assert_redirected_to customers_path
  end

  test "should not destroy customer that has been used" do
    assert_difference('Customer.count', -1) do
      delete :destroy, id: @customer
    end

    assert_redirected_to customers_path
  end  
end
