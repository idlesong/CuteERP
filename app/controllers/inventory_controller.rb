class InventoryController < ApplicationController
  skip_before_action :authorize

  def index
    @items = Item.all
  end
end
