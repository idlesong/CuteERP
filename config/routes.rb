Rails.application.routes.draw do
  get "up" => "rails/health#show", as: :rails_health_check

  resources :quotations

  resources :price_lists, only: [:index] do
    collection do
      post :create_entry
      delete :destroy_generic
      post :import
    end
  end

  resources :sales_orders do
    member do
      get :production
      get :confirm
      patch :update_production
      patch :submit
      post :add_line
      delete :remove_line
      post :create_shipment
      post :quick_ship
      get :invoice
      get :packing_list
    end
  end

  resources :shipments, only: [:index, :create, :destroy]

  resources :sales_plans, only: [:index, :create, :destroy] do
    collection { post :import }
  end

  resources :attachments

  resources :prices do
    member { get :apply }
    collection { get :options; post :import }
  end

  resources :posts
  resources :tasks
  resources :oppostatuses
  resources :opportunities
  resources :contacts

  resources :customers do
    collection { post :import }
  end

  controller :sessions do
    get "login" => :new
    post "login" => :create
    get "logout" => :destroy
  end

  resources :users

  resources :exchange_rates, only: [:index, :create, :destroy]

  resources :orders do
    collection do
      get :next_line_no
      post :import
    end
    member do
      patch :submit
      get :new_return
      post :create_return
    end
    resources :order_lines, only: [:create, :destroy]
  end

  resources :items do
    member { get :who_bought }
    collection { post :import }
  end

  get "workbench", to: "admin#workbench", as: :workbench

  get "inventory", to: "inventory#index", as: :inventory

  root "admin#index", as: :admin
end
