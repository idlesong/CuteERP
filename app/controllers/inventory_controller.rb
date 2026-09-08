class InventoryController < ApplicationController
  skip_before_action :authorize

  def index
    @items = Item.all
    @cart = current_cart
  end
end
