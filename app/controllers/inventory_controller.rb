class InventoryController < ApplicationController
  skip_before_filter :authorize

  def index
  	@items = Item.all 
  	@cart = current_cart
  end
end
