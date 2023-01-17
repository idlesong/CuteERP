require 'test_helper'

class OrderingFlowsTest < ActionDispatch::IntegrationTest
  setup do
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

  test "should create price" do
    assert_difference('Price.count') do
      post :create, price: @price_attributes
    end

    assert_redirected_to price_path(assigns(:price))
  end

  test "should create order" do
    @cart = Cart.create
    @cart.add_po_line_item(@price.id, @price.item.partNo, 5000, 40, nil)

    assert_difference('Order.count') do
      post :create, order: @order2_attributes
    end

    assert_redirected_to @order
  end


  test "ordering flows from price to order to sales order" do
    # 1. price
    #   - create price requst(set status approved)

    # 2. order (use special price, and support chipset items, and usd currency customers)
    #   - create prices for usd & rmb customers
    #   - create orders for usd & rmb customers
    #   - add more two more items(chipsets) for each order

    # 3. sales order(issue from order lineitems, part or multiply)
    #   - issue part quantity of one lineitem
    #   - issue total quantity of multiply lineitems
    #   - make invoice
    #   - make shippment
    #   - enter ship status
  end

  test "should cretae a order from price" do
  end

  test "should create reverse order" do
  end

  test "should create salese order" do
  end

  test "edit sales order should also issue back to order" do
  end
  
end
