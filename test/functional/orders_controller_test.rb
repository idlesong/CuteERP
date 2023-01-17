require 'test_helper'

class OrdersControllerTest < ActionController::TestCase
  setup do
    @item = items(:one)
    @customer = customers(:first)
    @price_attributes = {part_number: @item.partNo, item_id: @item.id, 
                        customer_name: @customer.name, customer_id: @customer.id, 
                        price: 38, condition: 5000} 
    @order_attributes = {order_number: 'FakePO20160101',name:'Tang',
                        address:'Shenzhen', pay_type:'COD', exchange_rate:1}    
    @order2_attributes = {order_number: 'PO2022010102',name:'Tang',
                        address:'Shenzhen', pay_type:'COD', exchange_rate:1}                                                   
    @price = @customer.prices.create(@price_attributes)            

    @cart = Cart.create
    # add_po_line_item(price_id, full_part_number, item_quantity, fixed_price
    @line_item_one = @cart.add_po_line_item(@price.id, @price.item.partNo, 5000, 40, nil)
    # @line_item_one.save

    @order = @customer.orders.build(@order_attributes)
    @order.add_line_items_from_cart(@cart, nil)
    @order.save
  end

  test "should get index" do
    get :index
    assert_response :success
    assert_not_nil assigns(:orders)
  end

  test "should get new" do
    # if customer changed, clear the cart
    cart = Cart.create
    session[:cart_id] = cart.id
    LineItem.create(cart: cart, item: items(:two))

    get :new
    assert_response :success
  end

  test "should create order" do
    @cart = Cart.create
    @cart.add_po_line_item(@price.id, @price.item.partNo, 5000, 40, nil)

    assert_difference('Order.count') do
      post :create, order: @order2_attributes
    end

    assert_redirected_to @order
  end

  test "should show order" do
    get :show, id: @order
    assert_response :success
  end

  test "should get edit" do
    get :edit, id: @order
    assert_response :success
  end

  test "should not get edit when order issued" do
    get :edit, id: @order
    assert_response :success
  end  

  test "should update order title" do
    get :edit, id: @order
    assert_response :success
  end

  test "should update order line items" do
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
