require 'test_helper'

class PricesControllerTest < ActionController::TestCase
  setup do
    @price = prices(:one)
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
      post :create, price: { boss_suggestion: @price.boss_suggestion, condition: @price.condition, customer_id: @price.customer_id, department_suggestion: @price.department_suggestion, finance_suggestion: @price.finance_suggestion, item_id: @price.item_id, payment_terms: @price.payment_terms, price: @price.price, sales_suggestion: @price.sales_suggestion }
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
    put :update, id: @price, price: { boss_suggestion: @price.boss_suggestion, condition: @price.condition, customer_id: @price.customer_id, department_suggestion: @price.department_suggestion, finance_suggestion: @price.finance_suggestion, item_id: @price.item_id, payment_terms: @price.payment_terms, price: @price.price, sales_suggestion: @price.sales_suggestion }
    assert_redirected_to price_path(assigns(:price))
  end

  test "should destroy price" do
    assert_difference('Price.count', -1) do
      delete :destroy, id: @price
    end

    assert_redirected_to prices_path
  end
end
