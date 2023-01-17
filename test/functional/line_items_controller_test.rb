require 'test_helper'

class LineItemsControllerTest < ActionController::TestCase
  setup do
    @line_item = line_items(:line1)
    @price_alpha = prices(:alpha)

    @customer = customers(:first)
    @price_attributes = {price: 30, condition: 5000, part_number: items(:one).partNo, 
                        customer_name: "1stCustomer", item_id: items(:one).id, 
                        customer_id: customers(:first) }
    @price = Price.create(@price_attributes)                    

    @order_attributes = {
      order_number: "PO202212003", 
      customer_id: @customer.id,
      pay_type: "COD",
      exchange_rate: 1,
    }
    @line_attributes = {
      fixed_price: 38, quantity: 10000, quantity_issued: 0
    }
    @order = Order.new(@order_attributes)    
    @order.line_items.new(@line_attributes)
    @order.save    
    @po_line = LineItem.find_by_line_number("LONew003")
  end

  test "should get index" do
    get :index
    assert_response :success
    assert_not_nil assigns(:line_items)
  end

  test "should get new" do
    get :new
    assert_response :success
  end

  # POST /line_items?item_id=3  ;po_cart: add line_item 
  # POST /line_items?line_id=3  ;so_cart: add issue_line_item
  # POST /line_items?line_id=3?reverse_order=true; po_cart add line_item  
  test "should add po line_item via ajax" do
    assert_difference('LineItem.count') do
      xhr :post, :create, :item_id => items(:one).id, :price_id => @price_alpha.id, :quantity => 3000
    end

    assert_response :success
    #assert_select_js :replace_html, 'cart' do
    #  assert_select 'tr#current_item td', /SCT3252/
    #end
  end

  test "should add so line_item via ajax" do
    assert_difference('LineItem.count') do
      xhr :post, :create, :line_id => line_items(:line1).id, :quantity => 3000
    end

    assert_response :success
    #assert_select_js :replace_html, 'cart' do
    #  assert_select 'tr#current_item td', /SCT3252/
    #end
  end  

  test "should issue_unissue po line_item via ajax" do
    assert_difference('LineItem.count') do
      xhr :post, :create, :line_id => line_items(:line1).id, :quantity => 3000
    end

    assert_response :success
    #assert_select_js :replace_html, 'cart' do
    #  assert_select 'tr#current_item td', /SCT3252/
    #end
  end

  test "should show line_item" do
    get :show, id: @line_item
    assert_response :success
  end

  test "should get edit" do
    get :edit, id: @line_item
    assert_response :success
  end

  test "should update line_item" do
    put :update, id: @line_item, line_item: { cart_id: @line_item.cart_id, item_id: @line_item.item_id }
    assert_redirected_to line_item_path(assigns(:line_item))
  end

  test "should destroy line_item" do
    assert_difference('LineItem.count', -1) do
      delete :destroy, id: @line_item
    end

    assert_redirected_to line_items_path
  end  

end
