class InventoryController < ApplicationController
  def index
  	@items = Item.all 
  	@cart = current_cart
  end
end
