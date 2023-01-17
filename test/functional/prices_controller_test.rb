require 'test_helper'

class PricesControllerTest < ActionController::TestCase
  # present: price, condition, part_number, customer_name, item_id, customer_id,  
  setup do
    @price = prices(:alpha)
    @input_attributes = {price: 30, condition: 5000, part_number: "partNo007", 
                        customer_name: "1stCustomer", item_id: items(:one).id, 
                        customer_id: customers(:first) }
    @update_attributes = {price: 20, condition: 25000, part_number: "partNo007", 
                        customer_name: "1stCustomer", item_id: items(:one).id, 
                        customer_id: customers(:first) }                        
  end

  test "should get index" do
    get :index
    assert_response :success
    assert_not_nil assigns(:prices)
  end

  test "should get new" do
    get :new
    assert_response :success
  end

  test "should create price" do
    assert_difference('Price.count') do
      post :create, price: @input_attributes
    end

    assert_redirected_to price_path(assigns(:price))
  end

  test "should show price" do
    get :show, id: @price
    assert_response :success
  end

  test "should get edit" do
    get :edit, id: @price
    assert_response :success
  end

  test "should update price" do
    put :update, id: @price, price: @update_attributes
    assert_redirected_to price_path(assigns(:price))
  end

  test "should destroy price" do
    assert_difference('Price.count', -1) do
      delete :destroy, id: @price
    end

    assert_redirected_to prices_path
  end
end
