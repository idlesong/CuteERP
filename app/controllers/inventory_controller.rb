class InventoryController < ApplicationController
  def index
  	@items = Item.all 
  end
end
