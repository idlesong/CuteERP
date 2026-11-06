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
      post :attach
      delete :detach
    end
    resources :order_lines, only: [:create, :destroy]
  end

  resources :items do
    member { get :who_bought }
    collection { post :import }
  end

  get "workbench", to: "admin#workbench", as: :workbench

  get "exports", to: "exports#index", as: :exports
  get "exports/monthly", to: "exports#monthly", as: :monthly_export
  get "exports/all", to: "exports#export_all", as: :export_all

  get "statements", to: "statements#show", as: :statement
  get "statements/export", to: "statements#export", as: :export_statement
  get "statements/export_internal", to: "statements#export_internal", as: :export_internal_statement
  get "statements/export_summary", to: "statements#export_summary", as: :export_summary_statement

  resources :closed_periods, only: [:index, :create, :destroy]

  get "imports", to: "imports#index", as: :imports
  post "imports/customer_orders", to: "imports#import_customer_orders", as: :import_customer_orders_imports
  post "imports/sales_orders", to: "imports#import_sales_orders", as: :import_sales_orders_imports
  post "imports/prices", to: "imports#import_prices", as: :import_prices_imports
  post "imports/shipments", to: "imports#import_shipments", as: :import_shipments_imports
  get "imports/check_file/:token", to: "imports#check_file", as: :import_check_file
  post "imports/customers", to: "imports#import_customers", as: :import_customers_imports
  post "imports/items", to: "imports#import_items", as: :import_items_imports

  get "inventory", to: "inventory#index", as: :inventory

  root "admin#index", as: :admin
end
