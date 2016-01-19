require 'test_helper'

class SalesOrdersControllerTest < ActionController::TestCase
  setup do
    @sales_order = sales_orders(:one)
  end

  test "should get index" do
    get :index
    assert_response :success
    assert_not_nil assigns(:sales_orders)
  end

  test "should get new" do
    get :new
    assert_response :success
  end

  test "should create sales_order" do
    assert_difference('SalesOrder.count') do
      post :create, sales_order: { bill_address: @sales_order.bill_address, bill_contact: @sales_order.bill_contact, bill_telephone: @sales_order.bill_telephone, customer_id: @sales_order.customer_id, payment_term: @sales_order.payment_term, serial_number: @sales_order.serial_number, ship_address: @sales_order.ship_address, ship_contact: @sales_order.ship_contact, ship_telephone: @sales_order.ship_telephone }
    end

    assert_redirected_to sales_order_path(assigns(:sales_order))
  end

  test "should show sales_order" do
    get :show, id: @sales_order
    assert_response :success
  end

  test "should get edit" do
    get :edit, id: @sales_order
    assert_response :success
  end

  test "should update sales_order" do
    put :update, id: @sales_order, sales_order: { bill_address: @sales_order.bill_address, bill_contact: @sales_order.bill_contact, bill_telephone: @sales_order.bill_telephone, customer_id: @sales_order.customer_id, payment_term: @sales_order.payment_term, serial_number: @sales_order.serial_number, ship_address: @sales_order.ship_address, ship_contact: @sales_order.ship_contact, ship_telephone: @sales_order.ship_telephone }
    assert_redirected_to sales_order_path(assigns(:sales_order))
  end

  test "should destroy sales_order" do
    assert_difference('SalesOrder.count', -1) do
      delete :destroy, id: @sales_order
    end

    assert_redirected_to sales_orders_path
  end
end
