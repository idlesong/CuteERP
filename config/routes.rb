Rails.application.routes.draw do
  get "up" => "rails/health#show", as: :rails_health_check

  resources :quotations

  resources :price_lists, only: [:index] do
    collection do
      post :create_entry
      post :import
    end
  end

  resources :sales_orders do
    member do
      get :edit_production
      get :production
      get :confirm
      get :invoice
      get :packing_list
      put :reschedule
      put :update_production
    end
  end

  resources :attachments

  resources :prices do
    member { get :apply }
    collection { post :import }
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

  resources :line_items

  resources :items do
    member { get :who_bought }
    collection { post :import }
  end

  get "inventory", to: "inventory#index", as: :inventory

  root "admin#index", as: :admin
end
