require 'test_helper'

class OrdersControllerTest < ActionController::TestCase
  setup do
    @order = orders(:one)
  end

  test "should get index" do
    get :index
    assert_response :success
    assert_not_nil assigns(:orders)
  end

  test "should get new" do
    cart = Cart.create
    session[:cart_id] = cart.id
    LineItem.create(:cart => cart, :item => items(:ruby))

    get :new
    assert_response :success
  end

  test "should create order" do
    item1 = Item.create({name: 'Analog WalkieTalkie BB',	description: '模拟对讲机基带',
    	partNo: 'SRT3210', package: 'LQFP100', price: 12.0, mop: 490})

    assert_difference('Order.count') do
      post :create, order: { order_number: 'test201601', pay_type: 'COD',
        exchange_rate: 6.5}
    end

    assert_redirected_to inventory_path
  end

  test "should show order" do
    get :show, id: @order
    assert_response :success
  end

  test "should get edit" do
    get :edit, id: @order
    assert_response :success
  end

  test "should update order" do
    put :update, id: @order, order: { address: @order.address, email: @order.email, name: @order.name, pay_type: @order.pay_type }
    assert_redirected_to order_path(assigns(:order))
  end

  test "should destroy order" do
    assert_difference('Order.count', -1) do
      delete :destroy, id: @order
    end

    assert_redirected_to orders_path
  end

end
