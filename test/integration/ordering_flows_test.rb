require 'test_helper'

class OrderingFlowsTest < ActionDispatch::IntegrationTest
  # test "the truth" do
  #   assert true
  # end
  fixtures :users
  fixtures :items
  fixtures :customers
  fixtures :contact

  test "ordering flows from price to order to sales order" do
    # 1. price
    #   - make price requst(set status approved)

    # 2. order (use special price, and support chipset items, and usd currency customers)
    #   - create special prices for usd & rmb customers
    #   - create orders for usd & rmb customers
    #   - add more two more items(chipsets) for each order

    # 3. sales order(issue from order lineitems, part or multiply)
    #   - issue part quantity of one lineitem
    #   - issue total quantity of multiply lineitems
    #   - make invoice
    #   - make shippment
    #   - enter ship status
  end
end
